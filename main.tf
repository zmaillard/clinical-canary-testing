terraform {
  backend "azurerm" {
    resource_group_name = "RG-Terraform"
    storage_account_name = "clinterrastate"
    container_name = "tfstate"
    key = "prod.abterraform.tfstate"
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

variable "environment" {
  type = string
  default = "dev"
}

resource "azurerm_resource_group" "rg" {
    name = "RG_Clinical_AB_${var.environment}"
    location = var.location
}

resource "azurerm_cdn_profile" "cdn" {
  name = "Clinical-AB-CDN-${var.environment}"
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Standard_Microsoft"
}

resource "azurerm_storage_account" "staticwebstorage" {
    name = "clinicalabstatic${var.environment}"
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
    name = "clinicalabdata${var.environment}"
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


resource "azurerm_cdn_endpoint" "staticwebendpoint" {
    name = "clinicalabendpoint${var.environment}"
    profile_name = azurerm_cdn_profile.cdn.name
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    origin_host_header = azurerm_storage_account.staticwebstorage.primary_web_host

    origin {
        name = "clinicalaborigin${var.environment}"
        host_name = azurerm_storage_account.staticwebstorage.primary_web_host
    }
}
