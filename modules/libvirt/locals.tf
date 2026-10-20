locals {
  client_annotations = {
    annotations = {
      platform = "libvirt"
    }
  }

  launch_policy_defaults = {
    snp = 196608
    tdx = 268435456
  }

  // Prefer the explicit numeric policy, then the typed SNP policy, then the
  // platform default when no custom policy is provided.
  launch_security_policy = coalesce(
    var.cvm_launch_policy,
    var.cvm_platform.cpu.type == "snp" ? local.snp_policy_from_object : null,
    local.launch_policy_defaults[var.cvm_platform.cpu.type],
  )

  // Libvirt launch_security config depending on hardware type
  launch_security = ({
    sevsnp = var.cvm_platform.cpu.type == "snp" ? {
      cbit_pos = 51
      policy   = local.launch_security_policy
    } : null
    tdx = var.cvm_platform.cpu.type == "tdx" ? {
      policy = local.launch_security_policy
      quote_generation_service = {
        path = "/var/run/tdx-qgs/qgs.socket"
      }
    } : null
  })

  gpu_driver_version_defaults = {
    nvidia = 595
  }

  gpu_driver_version = var.cvm_platform.gpu != null ? coalesce(
    var.cvm_platform.gpu.driver_version,
    local.gpu_driver_version_defaults[var.cvm_platform.gpu.type]
  ) : null

  // Network configuration for IP assignment
  network_config = var.cvm_ip4 == "dhcp" ? templatefile("${path.module}/networking/dhcp.yml", {}) : templatefile("${path.module}/networking/ipv4.yml", {
    GATEWAY      = var.cvm_gateway
    IPV4_ADDRESS = var.cvm_ip4
  })

  // GiB size
  gigabyte = 1073741824 // 2^30
}
