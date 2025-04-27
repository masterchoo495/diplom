variable "flow" {
  type    = string
  default = "net"
}

variable "cloud_id" {
  type    = string
  default = "b1gh7lntkfu3q3fuj9dv"
}
variable "folder_id" {
  type    = string
  default = "b1ga21m64ma2dpqdgtvd"
}

variable "cfg" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 2
    core_fraction = 20
    storage = 10
  }
}

