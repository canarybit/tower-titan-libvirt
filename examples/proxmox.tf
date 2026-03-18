terraform {
  required_version = ">= 0.14.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.85.0"
    }
  }
}

// AMD SEV-SNP and Intel TDX requires root@pam authentication
// See https://registry.terraform.io/providers/bpg/proxmox/latest/docs#example-usage
// Using snippets (cloud-init) requires ssh.
// See https://registry.terraform.io/providers/bpg/proxmox/latest/docs#when-is-ssh-required
provider "proxmox" {
  insecure = true
  ssh {
    agent = true
  }
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
  count = 2

  source = "../modules/proxmox"

  cb_username = var.cb_username
  cb_password = var.cb_password

  // Confidential VM
  cvm_name = "demo-cvm-${count.index}"

  // Remote Attestation
  cvm_platform = "snp"
  remote_attestation = {}

  // The image is assumed to be already uploaded to Proxmox
  // See https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file
  // for how to manage images with terraform.
  cloud_image_id = "local:iso/ubuntu-25.10-server-cloudimg-amd64.img"
}

// ========================
//  Print CVM info
// ========================
output "cvm-info" {
  value = module.confidential-vm.*.cvm-info
}
