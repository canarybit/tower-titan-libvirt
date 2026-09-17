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

variable "cvm_cpu_platform" {
  description = <<-EOT
    Type of Confidential CPU hardware platform
    cvm_cpu_platform = {
      type     - CPU hardware type: ['snp', 'tdx']
      firmware - (Optional) Path to custom firmware OVMF file.
    }
  EOT

  type = object({
    type     = string
    firmware = optional(string)
  })

  validation {
    condition     = contains(["snp", "tdx"], var.cvm_cpu_platform.type)
    error_message = "The value has to be one of the following: ['snp', 'tdx']"
  }
}

variable "cvm_name" {
  description = "Confidential VM name"
  type        = string
}

variable "cvm_cloud_image" {
  description = "Path to the CVM cloud image. The image is assumed to be already uploaded to Libvirt."
  type        = string
}

variable "remote_attestation" {
  description = "Enable CanaryBit Remote Attestation"
  type = object({
    cb_inspector_url            = optional(string, "https://api.inspector.confidentialcloud.io")
    cb_inspector_client_version = optional(string, "0.1.0")
    cbcli_version               = optional(string, "0.2.6")
    signing_key                 = optional(string)
    custom_policy_file          = optional(string)
    frequency                   = optional(string, "daily")
  })

  validation {
    condition     = contains(["minutely", "hourly", "daily", "weekly", "monthly"], var.remote_attestation.frequency)
    error_message = "The frequency has to be one of the following: minutely, hourly, daily, weekly, monthly"
  }
}

variable "cvm_secure_boot" {
  description = "Whether Secure Boot should be enabled in the firmware (yes, no). Default (not set): let libvirt decide based on the available firmware."
  type        = bool
  default     = null
}

variable "cvm_launch_policy" {
  description = "Launch security policy"
  type        = number
  default     = null
}

///////////////////////
// DEFAULT
///////////////////////
variable "cvm_snp_policy" {
  description = "Optional SEV-SNP guest policy settings"

  // The fields below map directly to the documented SEV-SNP policy bits.
  // Reserved bits 63:26 and mandatory bit 17 are managed automatically.
  // SMT is enabled by default but can be explicitly disabled.
  type = object({
    page_swap_disable      = optional(bool, false)
    ciphertext_hiding_dram = optional(bool, false)
    rapl_dis               = optional(bool, false)
    mem_aes_256_xts        = optional(bool, false)
    cxl_allow              = optional(bool, false)
    single_socket          = optional(bool, false)
    debug                  = optional(bool, false)
    migrate_ma             = optional(bool, false)
    smt                    = optional(bool, true)
    abi_major              = optional(number, 0)
    abi_minor              = optional(number, 0)
  })
  default = null

  validation {
    condition = var.cvm_snp_policy == null || (
      var.cvm_snp_policy.abi_major >= 0 &&
      var.cvm_snp_policy.abi_major <= 255 &&
      floor(var.cvm_snp_policy.abi_major) == var.cvm_snp_policy.abi_major &&
      var.cvm_snp_policy.abi_minor >= 0 &&
      var.cvm_snp_policy.abi_minor <= 255 &&
      floor(var.cvm_snp_policy.abi_minor) == var.cvm_snp_policy.abi_minor
    )
    error_message = "cvm_snp_policy abi_major and abi_minor must be integers between 0 and 255."
  }
}

variable "cloud_init" {
  description = "Custom cloud-init configuration"
  type = object({
    custom_path = optional(string)
    extra_args  = optional(map(any), {})
  })
  default = {}

  validation {
    condition     = !(var.cloud_init.custom_path == null && length(var.cloud_init.extra_args) > 0)
    error_message = "A custom_path is required when using extra_args in cloud_init"
  }
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

variable "libvirt_pool" {
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

variable "cvm_annotations" {
  description = "Custom annotations in \"<Key>\" = \"<Value>\" format"
  type        = map(any)
  default     = {}
}
