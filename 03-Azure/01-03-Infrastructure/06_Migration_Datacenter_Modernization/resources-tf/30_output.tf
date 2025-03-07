output "lb-frontend-ip-address" {
  value = "http://${azurerm_public_ip.onprem-lb.ip_address}"
}