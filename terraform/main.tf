resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.cluster_name

  default_node_pool {
    name       = "agentpool"
    node_count = 1
    vm_size    = "Standard_B2ms"   
  }

  identity {
    type = "SystemAssigned"
  }
}
