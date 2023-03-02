data "azurerm_databricks_workspace" "wspace" {
  name                = "${local.prefix}-databricks-workspace-${local.version}"
  resource_group_name = "${local.prefix}-rg-${local.version}"
}