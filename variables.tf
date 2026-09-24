variable "ubuntu_image" {
  default = "/var/lib/libvirt/images/noble-server-cloudimg-amd64.img"
}

variable "pool" {
  default = "default"
}

variable "ssh_public_key" {
  default = "~/.ssh/id_ed25519.pub"
}
