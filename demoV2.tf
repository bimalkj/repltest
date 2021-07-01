terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.6.9-pre4"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "osver" {
  type = string
  default = "7"
  description = "CentOS version"

  validation {
    condition = ((var.osver=="7") || (var.osver=="8"))
    error_message = "Invalid version input. Only 7 and 8 is available."
  }
}

resource "libvirt_volume" "centos7-qcow2" {
  name = "db.qcow2"
  pool = "default"
  #source = "https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2"
  source = "./centos${var.osver}.qcow2"
  format = "qcow2"
}

data "template_file" "user_data" {
  template = "${file("${path.module}/cloud_init.cfg")}"
}

# Use CloudInit to add the instance
resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"
  user_data      = data.template_file.user_data.rendered
}

# Define KVM domain to create
resource "libvirt_domain" "vmhost1" {
  name   = "db${var.osver}"
  memory = "1024"
  vcpu   = 1

  network_interface {
    network_name = "default"
  }

  disk {
    volume_id = "${libvirt_volume.centos7-qcow2.id}"
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}

# Output Server IP
output "ip" {
  value = "${libvirt_domain.vmhost1.network_interface.0.addresses.0}"
} 
