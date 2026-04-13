terraform {
  required_version = ">= 0.14.0"
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.9.5"
    }
  }
}

provider "libvirt" {
  # Connection URI - defaults to qemu:///system if not specified
  # uri = "qemu:///system"

  # For user session:
  # uri = "qemu:///session"

  # For remote connections (not yet implemented):
  # uri = "qemu+ssh://user@remote-host/system"
}

// =====================
//  Tower Arguments
// =====================

// Needed for attestation
variable "cb_username" {
  description = "CanaryBit username"
  type        = string
  sensitive   = true
}

variable "cb_password" {
  description = "CanaryBit password"
  type        = string
  sensitive   = true
}

// =====================
//  Confidential VM (CVM)
// =====================

module "confidential-vm" {
  source = "../../modules/libvirt"

  cb_username = var.cb_username
  cb_password = var.cb_password

  // Confidential VM
  cvm_name = "demo-cvm-${count.index}"

  // Remote Attestation
  cvm_platform = "snp"
  remote_attestation = {}

  // The image is assumed to be already uploaded to Libvirt
  // https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/volume
  // for how to manage images with terraform.
  cloud_image_id = "/var/lib/libvirt/images/questing-server-cloudimg-amd64.img"
}

// ========================
//  Print CVM info
// ========================
output "cvm-info" {
  value = module.confidential-vm.*.cvm-info
}

output "vm_id" {
  value       = module.confidential-vm.*.id
  description = "Domain ID for VMs"
}
