terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "databricks" {
  host                        = data.azurerm_databricks_workspace.wspace.workspace_url
  azure_workspace_resource_id = data.azurerm_databricks_workspace.wspace.workspace_id
}