########################
## CATALOG PERMISSIONS #
########################
/*
  As the Unity Catalog module uses the Workspace API, you have to create manually the groups Owners, Contributors and Readers manually in your Databricks Account. See img/img.png
*/

resource "databricks_grants" "playground" {
  catalog = "playground"
  grant {
    principal  = "Owners"
    privileges = ["ALL_PRIVILEGES"]
  }
  grant {
    principal  = "Contributors"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "CREATE_FUNCTION", "CREATE_TABLE", "MODIFY"]
  }
  grant {
    principal  = "Readers"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}

############
## SCHEMAS #
############
resource "databricks_schema" "squirrel" {
  catalog_name = "playground"
  name         = "squirreldb"
  storage_root = format("abfss://%s@%s.dfs.core.windows.net/%s",
    "test-data-container",
    "playgroundtestdata",
    "squirrels"
  )
  comment    = "Database with data related to Squirrels"
  properties = {
    squad = "DE"
  }
}