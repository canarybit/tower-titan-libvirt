terraform {
  required_version = ">= 0.14.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.5"
    }
  }
}

provider "libvirt" {}

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
  count  = 1
  source = "../../modules/libvirt"

  cb_username = var.cb_username
  cb_password = var.cb_password

  // Confidential VM
  cvm_name = "demo-cvm-${count.index}"
  // The image is assumed to be already uploaded to Libvirt.
  // Refer to the provider libvirt_volume resource (https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/volume)
  // for how to manage images with Terraform.
  cvm_cloud_image = "/var/lib/libvirt/images/questing-server-cloudimg-amd64.img"

  cvm_platform = {
    cpu = { type = "snp" }
  }

  // Remote Attestation
  remote_attestation = {
    // custom_policy_file = "./my-policy.rego"
    // frequency = "daily"
  }

}

// ========================
//  Print CVM info
// ========================
output "cvm-info" {
  value = module.confidential-vm.*.cvm-info
}
