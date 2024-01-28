terraform {
  cloud {
    organization = "sseplc"

    workspaces {
      name = "sub-airtricitycms-dev-gbl-002"
    }
  }
  required_providers {
    azurerm = {
      source  = "azurerm"
      version = ">= 3.59.0"
    }
    azapi = {
      source = "Azure/azapi"
    }
  }
}
provider "azurerm" {
  features {
  }
  use_oidc = true
}

provider "azapi" {
}