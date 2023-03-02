locals {
  version = "001"
  prefix  = "db-unity-catalog"
  tags    = {
    Project     = "Unity Catalog"
    Environment = var.environment
    Owner       = "Leandro Szikora"
  }
}

variable "subscription_id" {}
variable "tenant_id" {}
variable "location" {}
variable "environment" {}
