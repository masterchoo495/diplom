
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

#----------сreate bastion host
resource "yandex_compute_instance" "vm-bastion" {
  name        = "vm-bastion"
  hostname    = "vm-bastion"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data          = file("./cloud-init-bastion.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.bastion.id]
  }
}

#----------create web server 1
resource "yandex_compute_instance" "vm-web1" {
  name        = "vm-web1"
  hostname    = "vm-web1"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]
  }
}

#----------create web server 2
resource "yandex_compute_instance" "vm-web2" {
  name        = "vm-web2"
  hostname    = "vm-web2"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]

  }
}

#----------create zabbix host
resource "yandex_compute_instance" "vm-zabbix" {
  name        = "vm-zabbix"
  hostname    = "vm-zabbix"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_b.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.zabbix.id]
  }
}

#----------сreate elastic host
resource "yandex_compute_instance" "vm-elastic" {
  name        = "vm-elastic"
  hostname    = "vm-elastic"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = 4
    memory        = 4
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id]
  }
}

#----------create kibana host
resource "yandex_compute_instance" "vm-kibana" {
  name        = "vm-kibana"
  hostname    = "vm-kibana"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_b.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.kibana.id]
  }
}

resource "local_file" "inventory" {
  content  = <<-XYZ
  [bastion]
  ${yandex_compute_instance.vm-bastion.network_interface.0.nat_ip_address}
  [webservers]
  ${yandex_compute_instance.vm-web1.network_interface.0.ip_address}
  ${yandex_compute_instance.vm-web2.network_interface.0.ip_address}
  [services]
  ${yandex_compute_instance.vm-zabbix.network_interface.0.ip_address}
  ${yandex_compute_instance.vm-elastic.network_interface.0.ip_address}
  ${yandex_compute_instance.vm-kibana.network_interface.0.ip_address}
  XYZ
  filename = "./hosts.ini"
}

#----------create shapshot schedule (every day at 1:00 am)
resource "yandex_compute_snapshot_schedule" "diplom" {
  name = "diplom-snap"

  schedule_policy {
    expression = "0 1 ? * *"
  }

  snapshot_count = 1

  retention_period = "168h"

  snapshot_spec {
    description = "diplom-spec"
  }

  disk_ids = [
    "${yandex_compute_instance.vm-bastion.boot_disk.0.disk_id}", 
    "${yandex_compute_instance.vm-web1.boot_disk.0.disk_id}",
    "${yandex_compute_instance.vm-web2.boot_disk.0.disk_id}",
    "${yandex_compute_instance.vm-elastic.boot_disk.0.disk_id}",
    "${yandex_compute_instance.vm-kibana.boot_disk.0.disk_id}",
    "${yandex_compute_instance.vm-zabbix.boot_disk.0.disk_id}",
    ]
}


