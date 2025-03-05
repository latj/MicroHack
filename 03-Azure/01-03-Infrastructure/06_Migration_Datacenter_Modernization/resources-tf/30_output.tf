output "lb-frontend-ip-address" {
  value = azurerm_public_ip.onprem-lb.ip_address
}