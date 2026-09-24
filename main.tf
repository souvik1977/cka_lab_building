terraform {
  required_version = ">= 1.5"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

############################################
# Base Ubuntu Cloud Image
############################################

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu24-base.qcow2"
  pool   = var.pool
  source = var.ubuntu_image
  format = "qcow2"
}

############################################
# Cloud-init Templates
############################################

data "template_file" "cp01_userdata" {
  template = file("${path.module}/cloud_init.tpl")

  vars = {
    hostname = "cp01"
    ssh_key  = file(pathexpand(var.ssh_public_key))
  }
}

data "template_file" "worker01_userdata" {
  template = file("${path.module}/cloud_init.tpl")

  vars = {
    hostname = "worker01"
    ssh_key  = file(pathexpand(var.ssh_public_key))
  }
}

data "template_file" "worker02_userdata" {
  template = file("${path.module}/cloud_init.tpl")

  vars = {
    hostname = "worker02"
    ssh_key  = file(pathexpand(var.ssh_public_key))
  }
}

############################################
# CP01 Disk
############################################

resource "libvirt_volume" "cp01_disk" {
  name           = "cp01.qcow2"
  pool           = var.pool
  base_volume_id = libvirt_volume.ubuntu_base.id

  size = 20 * 1024 * 1024 * 1024
}

############################################
# Worker01 Disk
############################################

resource "libvirt_volume" "worker01_disk" {
  name           = "worker01.qcow2"
  pool           = var.pool
  base_volume_id = libvirt_volume.ubuntu_base.id

  size = 15 * 1024 * 1024 * 1024
}

############################################
# Worker02 Disk
############################################

resource "libvirt_volume" "worker02_disk" {
  name           = "worker02.qcow2"
  pool           = var.pool
  base_volume_id = libvirt_volume.ubuntu_base.id

  size = 15 * 1024 * 1024 * 1024
}

############################################
# Cloud-init ISOs
############################################

resource "libvirt_cloudinit_disk" "cp01_init" {
  name      = "cp01-cloudinit.iso"
  user_data = data.template_file.cp01_userdata.rendered
}

resource "libvirt_cloudinit_disk" "worker01_init" {
  name      = "worker01-cloudinit.iso"
  user_data = data.template_file.worker01_userdata.rendered
}

resource "libvirt_cloudinit_disk" "worker02_init" {
  name      = "worker02-cloudinit.iso"
  user_data = data.template_file.worker02_userdata.rendered
}

############################################
# Control Plane VM
############################################

resource "libvirt_domain" "cp01" {

  name   = "cp01"
  memory = 3072
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.cp01_init.id

  disk {
    volume_id = libvirt_volume.cp01_disk.id
  }

  network_interface {
    network_name = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
  graphics {
    type = "vnc"
    listen_type = "none"
  }
  video {
  type = "virtio"
  }
}

############################################
# Worker01 VM
############################################

resource "libvirt_domain" "worker01" {

  name   = "worker01"
  memory = 2048
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.worker01_init.id

  disk {
    volume_id = libvirt_volume.worker01_disk.id
  }

  network_interface {
    network_name = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
  graphics {
    type = "vnc"
    listen_type = "none"
  }
  video {
  type = "virtio"
  }

}

############################################
# Worker02 VM
############################################

resource "libvirt_domain" "worker02" {

  name   = "worker02"
  memory = 2048
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.worker02_init.id

  disk {
    volume_id = libvirt_volume.worker02_disk.id
  }

  network_interface {
    network_name = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
  graphics {
    type = "vnc"
    listen_type = "none"
  }
  video {
  type = "virtio"
  }

}
