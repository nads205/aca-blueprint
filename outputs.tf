output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "api1_uri_primary" {
  value = azurerm_container_app.containerapp-api1-uks.ingress[0].fqdn
}

output "api2_uri_primary" {
  value = azurerm_container_app.containerapp-api2-uks.ingress[0].fqdn
}

output "ui_uri_primary" {
  value = azurerm_container_app.containerapp-ui-uks.ingress[0].fqdn
}

output "api1_uri_secondary" {
  value = azurerm_container_app.containerapp-api1-neu.ingress[0].fqdn
}

output "api2_uri_secondary" {
  value = azurerm_container_app.containerapp-api2-neu.ingress[0].fqdn
}

output "ui_uri_secondary" {
  value = azurerm_container_app.containerapp-ui-neu.ingress[0].fqdn
}

output "frontdoor_endpoint" {
  value = azurerm_cdn_frontdoor_endpoint.fd-endpoint.host_name
}

 