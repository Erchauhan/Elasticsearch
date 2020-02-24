resource "azurerm_lb" "elasticsearchlb" {
  name                = "es-${var.es_cluster}-load-balancer"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.elasticsearch.name}"

   frontend_ip_configuration {
    name                          = "es-${var.es_cluster}-es-PrivateIP"
    subnet_id                     = "${azurerm_subnet.elasticsearch_subnet.id}"
    private_ip_address            = "10.1.0.10"
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_backend_address_pool" "es-lb-backend" {
  resource_group_name   = "${azurerm_resource_group.elasticsearch.name}"
  loadbalancer_id       = "${azurerm_lb.elasticsearchlb.id}"
  name                  = "es-${var.es_cluster}-BackEndAddressPoolbastion"
}

resource "azurerm_lb_probe" "es-lb-probe" {
  resource_group_name    = "${azurerm_resource_group.elasticsearch.name}"
  loadbalancer_id        = "${azurerm_lb.elasticsearchlb.id}"
  name                   = "es-${var.es_cluster}-es-Probe"
  protocol               = "tcp"
  port                   =  80
  interval_in_seconds    =  5
  number_of_probes       =  2
}

resource "azurerm_lb_rule" "es-lbrule" {
  resource_group_name            = "${azurerm_resource_group.elasticsearch.name}"
  loadbalancer_id                = "${azurerm_lb.elasticsearchlb.id}"
  name                           = "es-${var.es_cluster}-es-lb-rules"
  protocol                       = "tcp"
  frontend_port                  =  80
  backend_port                   =  80
  frontend_ip_configuration_name = "es-${var.es_cluster}-es-PrivateIP"
  enable_floating_ip             = false
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.es-lb-backend.id}"
  idle_timeout_in_minutes        = 5
  probe_id                       = "${azurerm_lb_probe.es-lb-probe.id}"
  depends_on                     = ["azurerm_lb_probe.es-lb-probe"]
}

resource "azurerm_virtual_machine_scale_set" "master-nodes" {
  count = "${var.masters_count == "0" ? "0" : "1"}"

  name = "es-${var.es_cluster}-master-nodes"
  resource_group_name = "${azurerm_resource_group.elasticsearch.name}"
  location = "${var.azure_location}"
  sku {
    name = "${var.master_instance_type}"
    tier = "Standard"
    capacity = "${var.masters_count}"
  }
  upgrade_policy_mode = "Manual"
  overprovision = false

  os_profile {
    computer_name_prefix = "${var.es_cluster}-master"
    admin_username = "ubuntu"
    admin_password = "${random_string.vm-login-password.result}"
  }

  network_profile {
    name = "es-${var.es_cluster}-net-profile"
    primary = true

    ip_configuration {
      name = "es-${var.es_cluster}-ip-profile"
      primary= true
      subnet_id = "${azurerm_subnet.elasticsearch_subnet.id}"
    }
  }

  storage_profile_image_reference {
    id = "${data.azurerm_image.elasticsearch.id}"
  }

  storage_profile_os_disk {
    caching        = "ReadWrite"
    create_option  = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/ubuntu/.ssh/authorized_keys"
      key_data = "${file(var.key_path)}"
    }
  }
}
