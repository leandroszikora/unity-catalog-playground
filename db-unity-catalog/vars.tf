locals {
  version = "001"
  prefix  = "db-unity-catalog"
  tags    = {
    Project     = "Unity Catalog"
    Environment = var.environment
    Owner       = "Leandro Szikora"
  }
}

variable "metastore_label" { default = "metastore" }
variable "default_metastore_default_catalog_name" { default = "playground" }
variable "catalog_name" { default = "my_catalog" }
variable "subscription_id" {}
variable "tenant_id" {}
variable "location" {}
variable "environment" {}
