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

resource "azurerm_frontdoor_custom_https_configuration" "clinical_canary_custom_https" {
  frontend_endpoint_id  = azurerm_frontdoor.canary_frontdoor.frontend_endpoint[0].id
  custom_https_provisioning_enabled = false
}
resource "azurerm_frontdoor" "canary_frontdoor" {
  name                                         = "Clinical-Canary-FrontDoor"
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
  }

  backend_pool {
    name = "CanaryStorageBackend"
    backend {
      host_header = "clincanaryblue.blob.core.windows.net"
      address     = "clincanaryblue.blob.core.windows.net"
      http_port   = 80
      https_port  = 443
      priority    = 1
      weight      = 1000
    }

    backend {
      host_header = "clincanarygreen.blob.core.windows.net"
      address     = "clincanarygreen.blob.core.windows.net"
      http_port   = 80
      https_port  = 443
      priority    = 1
      weight      = 1000
    }

    load_balancing_name = "clin-canary-load-balancing"
    health_probe_name   = "clin-canary-health-probe"
  }

  frontend_endpoint {
    name                              = "Clinical-Canary-FrontEnd"
    host_name                         = "clin-canary-test.azurefd.net"
    session_affinity_enabled          = true
  }
}
