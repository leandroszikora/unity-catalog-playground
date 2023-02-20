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
resource "azurerm_databricks_workspace" "db_wspace_playground" {
  name                = "${local.prefix}-databricks-workspace-${local.version}"
  resource_group_name = azurerm_resource_group.rg_playground.name
  location            = azurerm_resource_group.rg_playground.location
  sku                 = "premium"
}


########################
## AZURE API CONNECTOR #
########################
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
resource "databricks_metastore" "metastore" {
  name         = "${local.prefix}-databricks-metastore-${local.version}"
  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.unity_catalog.name,
    azurerm_storage_account.unity_catalog.name)
  force_destroy = true
}

resource "databricks_metastore_data_access" "metastore_data_access" {
  depends_on   = [databricks_metastore.metastore]
  metastore_id = databricks_metastore.metastore.id
  name         = var.metastore_label
  azure_managed_identity {
    access_connector_id = azapi_resource.access_connector.id
  }
  is_default = true
}

resource "databricks_metastore_assignment" "default_metastore" {
  depends_on           = [databricks_metastore_data_access.metastore_data_access]
  workspace_id         = azurerm_databricks_workspace.db_wspace_playground.workspace_id
  metastore_id         = databricks_metastore.metastore.id
  default_catalog_name = var.default_metastore_default_catalog_name
}

##################
## UNITY CATALOG #
##################
resource "databricks_catalog" "catalog" {
  depends_on   = [databricks_metastore_assignment.default_metastore]
  metastore_id = databricks_metastore.metastore.id
  name         = var.catalog_name
}