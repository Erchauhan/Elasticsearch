data "azurerm_image" "elasticsearch" {
  name                = "elasticsearch-image"
  resource_group_name = "packer-elasticsearch-images"
  sort_descending     = true
}

data "azurerm_image" "kibana" {
  name                = "kibana-image"
  resource_group_name = "packer-elasticsearch-images"
  sort_descending     = true
}
