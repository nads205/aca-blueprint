data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.aca_name}"
  location = var.primary_location
  tags     = var.tags
}

#vnet already exists and is created by the subscription vending process
# resource "azurerm_virtual_network" "vnet" {
#   name                = "${var.aca_name}-vnet"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   address_space       = ["10.204.0.0/16"]
# }
#subnet creation needs to be done via a 
# resource "azurerm_subnet" "plssubnet" {
#   name                 = "plssubnet"
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   address_prefixes     = ["10.204.1.0/24"]
#   private_link_service_network_policies_enabled = false
# }

# resource "azurerm_subnet" "acasubnet" {
#   name                 = "acasubnet"
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   address_prefixes     = ["10.204.2.0/23"]
# }

module "subnet-with-nsg_aci_uks" {
  source  = "app.terraform.io/sseplc/subnet-with-nsg-advanced/azure"
  version = "1.2.2" #Enter latest version here

  location                        = "uksouth"
  subnet_name                     = "containersubnet"
  subnet_cidr_range               = "192.168.0.0/23"
  enable_private_network_policies = false
  service_endpoint_names          = ["Microsoft.Storage"]
  custom_security_rules = [
    {
      rule_name                    = "deny-inbound-udp"
      priority                     = "2000"
      direction                    = "Inbound"
      access                       = "Deny"
      protocol                     = "Udp"
      source_port_ranges           = ["*"]
      destination_port_ranges      = ["*"]
      source_address_prefixes      = ["10.0.0.0/8"]
      destination_address_prefixes = ["*"]
    },
    {
      rule_name                    = "deny-inbound-icmp"
      priority                     = "2001"
      direction                    = "Inbound"
      access                       = "Deny"
      protocol                     = "Icmp"
      source_port_ranges           = ["443", "445"]
      destination_port_ranges      = ["*"]
      source_address_prefixes      = ["10.0.0.0/8"]
      destination_address_prefixes = ["*"]
    }
  ]
}

module "subnet-with-nsg_aci_neu" {
  source  = "app.terraform.io/sseplc/subnet-with-nsg-advanced/azure"
  version = "1.2.2" #Enter latest version here

  location                        = "northeurope"
  subnet_name                     = "containersubnet"
  subnet_cidr_range               = "192.169.0.0/23"
  enable_private_network_policies = false
  service_endpoint_names          = ["Microsoft.Storage"]
  custom_security_rules = [
    {
      rule_name                    = "deny-inbound-udp"
      priority                     = "2000"
      direction                    = "Inbound"
      access                       = "Deny"
      protocol                     = "Udp"
      source_port_ranges           = ["*"]
      destination_port_ranges      = ["*"]
      source_address_prefixes      = ["10.0.0.0/8"]
      destination_address_prefixes = ["*"]
    },
    {
      rule_name                    = "deny-inbound-icmp"
      priority                     = "2001"
      direction                    = "Inbound"
      access                       = "Deny"
      protocol                     = "Icmp"
      source_port_ranges           = ["443", "445"]
      destination_port_ranges      = ["*"]
      source_address_prefixes      = ["10.0.0.0/8"]
      destination_address_prefixes = ["*"]
    }
  ]
}

resource "azurerm_log_analytics_workspace" "loganalytics" {
  name                = "${var.aca_name}-la"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appinsights" {
  name                = "${var.aca_name}-appinsights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.loganalytics.id
  application_type    = "web"
}

resource "azurerm_container_registry" "acr" {
  name                = "${var.aca_name}acr"
  sku                 = "Standard"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_container_app_environment" "containerappenv_uks" {
  name                           = "${var.aca_name}-uks-env"
  location                       = azurerm_resource_group.rg.location
  tags                           = var.tags
  resource_group_name            = azurerm_resource_group.rg.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.loganalytics.id
  infrastructure_subnet_id       = module.subnet-with-nsg_aci_uks.subnet_id
  internal_load_balancer_enabled = true
}

resource "azurerm_container_app_environment" "containerappenv_neu" {
  name                           = "${var.aca_name}-neu-env"
  location                       = var.secondary_location
  tags                           = var.tags
  resource_group_name            = azurerm_resource_group.rg.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.loganalytics.id
  infrastructure_subnet_id       = module.subnet-with-nsg_aci_neu.subnet_id
  internal_load_balancer_enabled = true
}

resource "azurerm_user_assigned_identity" "containerapp" {
  location            = azurerm_resource_group.rg.location
  name                = "${var.aca_name}uai"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "containerapp" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "acrpull"
  principal_id         = azurerm_user_assigned_identity.containerapp.principal_id
  depends_on = [
    azurerm_user_assigned_identity.containerapp
  ]
}

resource "azurerm_container_app" "containerapp-api1-uks" {
  name                         = "${var.aca_name}-uks-api1"
  tags                         = var.tags
  container_app_environment_id = azurerm_container_app_environment.containerappenv_uks.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Multiple"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.containerapp.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp.id
  }

  ingress {
    external_enabled = false
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  template {
    container {
      name   = "helloworldcontainerapp"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}

resource "azurerm_container_app" "containerapp-api1-neu" {
  name                         = "${var.aca_name}-neu-api1"
  tags                         = var.tags
  container_app_environment_id = azurerm_container_app_environment.containerappenv_neu.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Multiple"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.containerapp.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp.id
  }

  ingress {
    external_enabled = false
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  template {
    container {
      name   = "helloworldcontainerapp"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}

resource "azurerm_container_app" "containerapp-api2-uks" {
  name                         = "${var.aca_name}-uks-api2"
  tags                         = var.tags
  container_app_environment_id = azurerm_container_app_environment.containerappenv_uks.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Multiple"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.containerapp.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp.id
  }

  ingress {
    external_enabled = false
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  template {
    container {
      name   = "helloworldcontainerapp"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}

resource "azurerm_container_app" "containerapp-api2-neu" {
  name                         = "${var.aca_name}-neu-api2"
  tags                         = var.tags
  container_app_environment_id = azurerm_container_app_environment.containerappenv_neu.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Multiple"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.containerapp.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp.id
  }

  ingress {
    external_enabled = false
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  template {
    container {
      name   = "helloworldcontainerapp"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}

resource "azurerm_container_app" "containerapp-ui-uks" {
  name                         = "${var.aca_name}-uks-ui"
  tags                         = var.tags
  container_app_environment_id = azurerm_container_app_environment.containerappenv_uks.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Multiple"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.containerapp.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp.id
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  template {
    container {
      name   = "helloworldcontainerapp"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name  = "API1_URL"
        value = azurerm_container_app.containerapp-api1-uks.ingress[0].fqdn
      }
      env {
        name  = "API2_URL"
        value = azurerm_container_app.containerapp-api2-uks.ingress[0].fqdn
      }

      readiness_probe {
        transport = "HTTP"
        port      = 80
      }

      liveness_probe {
        transport = "HTTP"
        port      = 80
      }

      startup_probe {
        transport = "HTTP"
        port      = 80
      }
    }
  }
}

resource "azurerm_container_app" "containerapp-ui-neu" {
  name                         = "${var.aca_name}-neu-ui"
  tags                         = var.tags
  container_app_environment_id = azurerm_container_app_environment.containerappenv_neu.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Multiple"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.containerapp.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp.id
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  template {
    container {
      name   = "helloworldcontainerapp"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name  = "API1_URL"
        value = azurerm_container_app.containerapp-api1-neu.ingress[0].fqdn
      }
      env {
        name  = "API2_URL"
        value = azurerm_container_app.containerapp-api2-neu.ingress[0].fqdn
      }

      readiness_probe {
        transport = "HTTP"
        port      = 80
      }

      liveness_probe {
        transport = "HTTP"
        port      = 80
      }

      startup_probe {
        transport = "HTTP"
        port      = 80
      }
    }
  }
}

// section for key vault
# resource "azurerm_key_vault" "kv" {
#   name                        = "${var.aca_name}kv"
#   location                    = azurerm_resource_group.rg.location
#   resource_group_name         = azurerm_resource_group.rg.name
#   enabled_for_disk_encryption = true
#   tenant_id                   = data.azurerm_client_config.current.tenant_id
#   soft_delete_retention_days  = 7
#   purge_protection_enabled    = false

#   sku_name = "standard"

#   access_policy {
#     tenant_id = data.azurerm_client_config.current.tenant_id
#     object_id = data.azurerm_client_config.current.object_id

#     key_permissions = [
#       "Get",
#     ]

#     secret_permissions = [
#       "Get",
#     ]

#     storage_permissions = [
#       "Get",
#     ]
#   }
# }

// section for private link service
data "azurerm_lb" "kubernetes-internal-uks" {
  name                = "kubernetes-internal"
  resource_group_name = format("MC_%s-rg_%s_%s", split(".", azurerm_container_app.containerapp-ui-uks.ingress[0].fqdn)[1], split(".", azurerm_container_app.containerapp-ui-uks.ingress[0].fqdn)[1], azurerm_resource_group.rg.location)
}
resource "azurerm_private_link_service" "pls-uks" {
  name                = "${var.aca_name}-uks-pls"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  visibility_subscription_ids                 = [data.azurerm_client_config.current.subscription_id]
  load_balancer_frontend_ip_configuration_ids = [data.azurerm_lb.kubernetes-internal-uks.frontend_ip_configuration.0.id]
  auto_approval_subscription_ids              = [data.azurerm_client_config.current.subscription_id]

  nat_ip_configuration {
    name                       = "primary"
    private_ip_address_version = "IPv4"
    subnet_id                  = module.subnet-with-nsg_aci_uks.subnet_id
    primary                    = true
  }
}

// section for private link service
data "azurerm_lb" "kubernetes-internal-neu" {
  name                = "kubernetes-internal"
  resource_group_name = format("MC_%s-rg_%s_%s", split(".", azurerm_container_app.containerapp-ui-neu.ingress[0].fqdn)[1], split(".", azurerm_container_app.containerapp-ui-neu.ingress[0].fqdn)[1], var.secondary_location)
}
resource "azurerm_private_link_service" "pls-neu" {
  name                = "${var.aca_name}-neu-pls"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.secondary_location

  visibility_subscription_ids                 = [data.azurerm_client_config.current.subscription_id]
  load_balancer_frontend_ip_configuration_ids = [data.azurerm_lb.kubernetes-internal-neu.frontend_ip_configuration.0.id]
  auto_approval_subscription_ids              = [data.azurerm_client_config.current.subscription_id]

  nat_ip_configuration {
    name                       = "primary"
    private_ip_address_version = "IPv4"
    subnet_id                  = module.subnet-with-nsg_aci_neu.subnet_id
    primary                    = true
  }
}

// section for front door service
resource "azurerm_cdn_frontdoor_profile" "fd-profile" {
  depends_on = [azurerm_private_link_service.pls-uks,azurerm_private_link_service.pls-neu]

  name                = "${var.aca_name}-fd"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Premium_AzureFrontDoor"
}
resource "azurerm_cdn_frontdoor_endpoint" "fd-endpoint" {
  name                     = "${var.aca_name}-fdendpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd-profile.id
}
resource "azurerm_cdn_frontdoor_origin_group" "fd-origin-group" {
  name                     = "${var.aca_name}-fdorigingroup"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd-profile.id

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 16
    successful_samples_required        = 3
  }
}
resource "azurerm_cdn_frontdoor_route" "fd-route" {
  name                          = "${var.aca_name}-fdroute"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fd-endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd-origin-group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.fd-origin-uks.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
  https_redirect_enabled = true
}
resource "azurerm_cdn_frontdoor_origin" "fd-origin-uks" {
  name                           = "${var.aca_name}-uks-fdorigin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.fd-origin-group.id
  enabled                        = true
  host_name                      = azurerm_container_app.containerapp-ui-uks.ingress[0].fqdn
  origin_host_header             = azurerm_container_app.containerapp-ui-uks.ingress[0].fqdn
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true

  private_link {
    request_message        = "Request access for Private Link Origin CDN Frontdoor"
    location               = azurerm_resource_group.rg.location
    private_link_target_id = azurerm_private_link_service.pls-uks.id
  }
}

resource "azurerm_cdn_frontdoor_origin" "fd-origin-neu" {
  name                           = "${var.aca_name}-neu-fdorigin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.fd-origin-group.id
  enabled                        = true
  host_name                      = azurerm_container_app.containerapp-ui-neu.ingress[0].fqdn
  origin_host_header             = azurerm_container_app.containerapp-ui-neu.ingress[0].fqdn
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true

  private_link {
    request_message        = "Request access for Private Link Origin CDN Frontdoor"
    location               = var.secondary_location
    private_link_target_id = azurerm_private_link_service.pls-neu.id
  }
}

