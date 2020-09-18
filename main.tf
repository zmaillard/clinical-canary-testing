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

variable "prefix" {
  type = string
  default = "" #String between 1 and 5 chars
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
    name = "${var.prefix}clincanaryblue"
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
    name = "${var.prefix}clincanarydata"
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

resource "azurerm_frontdoor_custom_https_configuration" "clinical_canary_custom_https" {
  frontend_endpoint_id  = azurerm_frontdoor.canary_frontdoor.frontend_endpoint[0].id
  custom_https_provisioning_enabled = false
}
resource "azurerm_frontdoor" "canary_frontdoor" {
  name                                         = "${var.prefix}Clinical-Canary-FrontDoor"
  resource_group_name                          = azurerm_resource_group.rg.name
  enforce_backend_pools_certificate_name_check = false

  routing_rule {
    name               = "Clinical-Canary-FrontDoor-Routing"
    accepted_protocols = ["Http", "Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["Clinical-Canary-FrontEnd"]
    forwarding_configuration {
      forwarding_protocol = "MatchRequest"
      backend_pool_name   = "CanaryStorageBackend"
    }
  }

  backend_pool_load_balancing {
    name = "clin-canary-load-balancing"
  }

  backend_pool_health_probe {
    name = "clin-canary-health-probe"
    path = "/index.html"
    protocol = "Https"
  }

  backend_pool {
    name = "CanaryStorageBackend"
    backend {
      host_header = "${var.prefix}clincanaryblue.z22.web.core.windows.net"
      address     = "${var.prefix}clincanaryblue.z22.web.core.windows.net"
      http_port   = 80
      https_port  = 443
      priority    = 1
      weight      = 500
    }

    backend {
      host_header = "${var.prefix}clincanarygreen.z22.web.core.windows.net"
      address     = "${var.prefix}clincanarygreen.z22.web.core.windows.net"
      http_port   = 80
      https_port  = 443
      priority    = 1
      weight      = 500
    }

    load_balancing_name = "clin-canary-load-balancing"
    health_probe_name   = "clin-canary-health-probe"
  }

  frontend_endpoint {
    name                              = "${var.prefix}Clinical-Canary-FrontEnd"
    host_name                         = "${var.prefix}Clinical-Canary-FrontDoor.azurefd.net"
    session_affinity_enabled          = true
  }
}
