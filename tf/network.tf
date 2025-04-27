#----------create cloud network
resource "yandex_vpc_network" "diplom" {
  name = "diplom-${var.flow}"
}

#----------create subnet zone A
resource "yandex_vpc_subnet" "diplom_a" {
  name           = "diplom-${var.flow}-ru-central1-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diplom.id
  v4_cidr_blocks = ["10.0.1.0/28"]
  route_table_id = yandex_vpc_route_table.rt.id
}

#----------create subnet zone B
resource "yandex_vpc_subnet" "diplom_b" {
  name           = "diplom-${var.flow}-ru-central1-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.diplom.id
  v4_cidr_blocks = ["10.0.2.0/28"]
  route_table_id = yandex_vpc_route_table.rt.id
}

#----------create NAT for internet access
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "gateway-${var.flow}"
  shared_egress_gateway {}
}

#----------create route table
resource "yandex_vpc_route_table" "rt" {
  name       = "route-table-${var.flow}"
  network_id = yandex_vpc_network.diplom.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

#----------create security group for bastion
resource "yandex_vpc_security_group" "bastion" {
  name       = "bastion-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id
  ingress {
    description    = "Allow 0.0.0.0/0"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#----------create security group for kibana
resource "yandex_vpc_security_group" "kibana" {
  name       = "kibana-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id
  ingress {
    description    = "Allow 0.0.0.0/0"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }
  ingress {
    description    = "Allow ICMP"
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/8"]
  }
  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#----------create security group for zabbix
resource "yandex_vpc_security_group" "zabbix" {
  name       = "zabbix-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id
  ingress {
    description    = "Allow 0.0.0.0/0"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 10051
  }
  ingress {
    description    = "Allow 0.0.0.0/0"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }
  ingress {
    description    = "Allow ICMP"
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/8"]
  }
  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#----------create security group for LAN
resource "yandex_vpc_security_group" "LAN" {
  name       = "LAN-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id
  ingress {
    description    = "Allow 10.0.0.0/8"
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.0.0/8"]
  }
  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#----------create security group for web servers
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id
  ingress {
    description    = "Allow HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description    = "Allow HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#---------create security group for lb
resource "yandex_vpc_security_group" "public_lb" {
  name       = "public-lb"
  network_id = yandex_vpc_network.diplom.id

  ingress {
    description       = "Health checks"
    protocol          = "ANY"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    description    = "Allow TCP"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    description    = "Allow ICMP"
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#----------create target group
resource "yandex_alb_target_group" "target_group" {
  name           = "target-group"
  target {
    subnet_id    = yandex_vpc_subnet.diplom_a.id
    ip_address   = yandex_compute_instance.vm-web1.network_interface.0.ip_address
  }

  target {
    subnet_id    = yandex_vpc_subnet.diplom_b.id
    ip_address   = yandex_compute_instance.vm-web2.network_interface.0.ip_address
  }
}

#----------create backend group
resource "yandex_alb_backend_group" "backend_group" {
  name                     = "backend-group"
  http_backend {
    name                   = "backend"
    weight                 = 1
    port                   = 80
    target_group_ids       = [yandex_alb_target_group.target_group.id]
    load_balancing_config {
      panic_threshold      = 90
    }
    healthcheck {
      timeout              = "10s"
      interval             = "2s"
      healthy_threshold    = 10
      unhealthy_threshold  = 15
      http_healthcheck {
        path = "/"
      }
    }
  }
}

#----------create http router
resource "yandex_alb_http_router" "http_router" {
  name          = "http-router"
}

#----------create virtual host
resource "yandex_alb_virtual_host" "virtual-host" {
  name                    = "virtual-host"
  http_router_id          = yandex_alb_http_router.http_router.id
  route {
    name                  = "diplom-route"
    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }
      http_route_action {
        backend_group_id  = yandex_alb_backend_group.backend_group.id
        timeout           = "5s"
      }
    }
  }
}

#----------create alb lb
resource "yandex_alb_load_balancer" "diplom_lb" {
  name        = "diplom-lb"
  network_id  = yandex_vpc_network.diplom.id
  security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.public_lb.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.diplom_b.id
    }
  }

  listener {
    name = "diplom-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 80 ]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.http_router.id
      }
    }
  }
}