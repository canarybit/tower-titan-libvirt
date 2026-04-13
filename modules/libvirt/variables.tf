///////////////////////
// REQUIRED
///////////////////////

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

variable "cvm_platform" {
  description = "Type of confidential machine snp/tdx"
  type        = string

  validation {
    condition     = contains(["snp", "tdx"], var.cvm_platform)
    error_message = "cvm_platform has to be either snp or tdx"
  }
}

variable "cvm_name" {
  description = "Confidential VM name"
  type        = string
}

variable "cloud_image_id" {
  description = "Image id used for cloud image"
  type        = string
}

///////////////////////
// DEFAULT
///////////////////////
variable "cloud_init" {
  description = "Custom cloud init configuration"
  type = object({
    custom_path = optional(string)
    extra_args  = optional(map(any), {})
  })
  default = {}

  validation {
    condition     = !(var.cloud_init.custom_path == null && length(var.cloud_init.extra_args) > 0)
    error_message = "a custom_path is required when using extra_args in cloud_init"
  }
}

variable "remote_attestation" {
  description = "Enable CanaryBit Remote Attestation"
  type = object({
    cbinspector_url  = optional(string, "https://api.inspector.confidentialcloud.io")
    cbclient_version = optional(string, "0.3.0")
    cbcli_version    = optional(string, "0.2.5")
    signing_key      = optional(string)
  })
  default = {}
}

variable "cvm_ip4" {
  description = "IP address of machine or dhcp for dynamic assignment"
  type        = string
  default     = "dhcp"

  validation {
    condition = (
      var.cvm_ip4 == "dhcp" ||
      (
        can(cidrhost("${var.cvm_ip4}", 0)) &&
        var.cvm_gateway != null
      )
    )
    error_message = "cvm_ip4 must be 'dhcp' or a valid IPv4 address. When using a static IP also set cvm_gateway"
  }
}

variable "cvm_gateway" {
  description = "Default gateway for machine. Ignored if cvm_ip4 is set to dhcp"
  type        = string
  default     = null
}

variable "pool" {
  description = "Libvirt pool"
  type        = string
  default     = "default"
}

variable "cvm_username" {
  description = "CVM Username for SSH login"
  type        = string
  default     = "tower"
}

variable "cvm_ssh_pubkey" {
  description = "Path to the public key used for SSH connection"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "cvm_cpu" {
  description = "CPU type"
  type        = string
  default     = "host-passthrough"
}

variable "cvm_firmware" {
  description = "Path to firmware (OVMF.fd)"
  type = string
  default = null # Default depends on cvm_platform, see locals
}

variable "cvm_vcpus" {
  description = "Number of vcpus (cores)"
  type        = number
  default     = 1
}

variable "cvm_ram" {
  description = "RAM size of the machine in MB"
  type        = number
  default     = 4096
}

variable "cvm_disk_size_gb" {
  description = "CVM Disk size"
  type        = number
  default     = 30
}

variable "cvm_network" {
  description = "Libvirt network"
  type        = string
  default     = "default"
}
