output "eventgrid_endpoint" {
    value = "${azurerm_eventgrid_domain.eventgrid.endpoint}"
}