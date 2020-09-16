terraform {
  backend "azurerm" {
    resource_group_name = "RG-Terraform"
    storage_account_name = "clinterrastate"
    container_name = "tfstate"
    key = "prod.canaryterraform.tfstate"
  }
}

provider "azurerm" {
  version = "~> 2.25.0"
  features { }
}


variable "location" {
  type = string
  default = "westus"
}

resource "azurerm_resource_group" "rg" {
    name = "RG_Clinical_Canary"
    location = var.location
}

resource "azurerm_storage_account" "staticwebstoragegreen" {
    name = "clincanarygreen"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    account_tier = "Standard"
    account_replication_type = "LRS"
    account_kind = "StorageV2"
    static_website  {
        index_document = "index.html"
    }
}

resource "azurerm_storage_account" "staticwebstorageblue" {
    name = "clincanaryblue"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    account_tier = "Standard"
    account_replication_type = "LRS"
    account_kind = "StorageV2"
    static_website  {
        index_document = "index.html"
    }
}
resource "azurerm_storage_account" "tablestorage" {
    name = "clincanarydata"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    account_tier = "Standard"
    account_replication_type = "LRS"
    account_kind = "StorageV2"
}

resource "azurerm_storage_table" "feature_flag" {
  name                 = "featureflag"
  storage_account_name = azurerm_storage_account.tablestorage.name
}

resource "azurerm_storage_table" "feedback" {
  name                 = "feedback"
  storage_account_name = azurerm_storage_account.tablestorage.name
}
