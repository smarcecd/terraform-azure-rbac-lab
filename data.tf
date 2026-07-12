# Read the resource group created in Lab 1
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

# Read the existing VM FS01 created in Lab 1
data "azurerm_virtual_machine" "fs01" {
  name                = var.vm_name
  resource_group_name = data.azurerm_resource_group.lab.name
}
