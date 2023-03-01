###################
## RESOURCE GROUP #
###################
resource "azurerm_resource_group" "rg_playground" {
  location = var.location
  name     = "${local.prefix}-rg-${local.version}"
  tags     = local.tags
}

#########################
## DATABRICKS WORKSPACE #
#########################
/*
  We need an Azure Databricks workspace to assign it to the Databricks TF provider. See db-unity-catalog/provider.tf
*/
resource "azurerm_databricks_workspace" "db_wspace_playground" {
  name                = "${local.prefix}-databricks-workspace-${local.version}"
  resource_group_name = azurerm_resource_group.rg_playground.name
  location            = azurerm_resource_group.rg_playground.location
  sku                 = "premium"
}


########################
## AZURE API CONNECTOR #
########################
/*
  Unity Catalog needs this access connector to obtain a Managed Identity to which we will assign roles.
*/
resource "azapi_resource" "access_connector" {
  type      = "Microsoft.Databricks/accessConnectors@2022-04-01-preview"
  name      = "${local.prefix}-databricks-mi-${local.version}"
  location  = azurerm_resource_group.rg_playground.location
  parent_id = azurerm_resource_group.rg_playground.id
  body      = jsonencode({ properties = {} })
  identity {
    type = "SystemAssigned"
  }
}

####################
## STORAGE ACCOUNT #
####################
/*
  This Storage Account will be used by Unity Catalog to store the data created using Managed Tables. Also audit information.
*/
resource "azurerm_storage_account" "unity_catalog" {
  name                     = replace("${local.prefix}storage${local.version}", "-", "")
  resource_group_name      = azurerm_resource_group.rg_playground.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "unity_catalog" {
  name                  = "${local.prefix}-container-${local.version}"
  storage_account_name  = azurerm_storage_account.unity_catalog.name
  container_access_type = "private"
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_storage_account.unity_catalog.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azapi_resource.access_connector.identity[0].principal_id
}

/*
  We will use this Storage Account to store test data and we will connect it with an External Location.
*/
resource "azurerm_storage_account" "test_data_sa" {
  name                     = "playgroundtestdata"
  resource_group_name      = azurerm_resource_group.rg_playground.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "test_data_cont" {
  name                  = "test-data-container"
  storage_account_name  = azurerm_storage_account.test_data_sa.name
  container_access_type = "private"
}

####################
## UNITY METASTORE #
####################
/*
  Creation of the Metastore, you can create one per region in a tenant.
*/
resource "databricks_metastore" "metastore" {
  name         = "${local.prefix}-databricks-metastore-${local.version}"
  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.unity_catalog.name,
    azurerm_storage_account.unity_catalog.name)
  force_destroy = true
}

/*
  Here we say that the metastore can access to the Storage Account using the created access connector.
*/
resource "databricks_metastore_data_access" "metastore_data_access" {
  depends_on   = [databricks_metastore.metastore]
  metastore_id = databricks_metastore.metastore.id
  name         = var.metastore_label
  azure_managed_identity {
    access_connector_id = azapi_resource.access_connector.id
  }
  is_default = true
}

/*
  We assign the metastore to the created workspace.
*/
resource "databricks_metastore_assignment" "default_metastore" {
  depends_on           = [databricks_metastore_data_access.metastore_data_access]
  workspace_id         = azurerm_databricks_workspace.db_wspace_playground.workspace_id
  metastore_id         = databricks_metastore.metastore.id
  default_catalog_name = var.default_metastore_default_catalog_name
}

######################
## EXTERNAL LOCATION #
######################
/*
  We will use the DB Access Connector in the Storage Credential. Furthermore, we need to assign the role to the specific scope (the playground SA).
*/
resource "azurerm_role_assignment" "external_mi_storage_role_assign" {
  scope                = azurerm_storage_account.test_data_sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azapi_resource.access_connector.identity[0].principal_id
}

/*
  This resource will be used by the External Location, then we can create catalogs that will use it.
*/
resource "databricks_storage_credential" "external_mi" {
  name = "mi_credential"
  azure_managed_identity {
    access_connector_id = azapi_resource.access_connector.id
  }
  comment    = "Managed identity credential managed by TF"
  depends_on = [databricks_metastore_assignment.default_metastore]
}

/*
  The external location points to a Storage Account.
*/
resource "databricks_external_location" "external_location_playground" {
  name = "playground_external"
  url  = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.test_data_cont.name,
    azurerm_storage_account.test_data_sa.name)
  credential_name = databricks_storage_credential.external_mi.id
  comment         = "Managed by TF"
  depends_on      = [azurerm_role_assignment.external_mi_storage_role_assign]
}