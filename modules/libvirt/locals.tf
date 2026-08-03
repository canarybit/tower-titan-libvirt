locals {
  // Merge default with custom annotations
  annotations = merge(var.cvm_annotations, {
    "canarybit" = "tower"
  })

  // cloud-init config template
  cloud_init_args = merge({
      HOSTNAME   = var.cvm_name
      USERNAME   = var.cvm_username
      SSH_PUBKEY = file(var.cvm_ssh_pubkey)
      // CanaryBit Remote Attestation
      CB_TOKENS               = data.http.cblogin.*.response_body[0]
      CBINSPECTOR_URL         = var.remote_attestation.cbinspector_url
      CBCLIENT_V              = var.remote_attestation.cbclient_version
      CBCLI_V                 = var.remote_attestation.cbcli_version
      ENVIRONMENTS            = var.cvm_cpu_platform.type
      CUSTOM_POLICY_OPT       = var.remote_attestation.custom_policy_file != null ? "--policy /etc/canarybit/custom-policy.rego" : ""
      CUSTOM_POLICY           = var.remote_attestation.custom_policy_file != null ? indent(6,file(var.remote_attestation.custom_policy_file)) : ""
      FREQUENCY               = var.remote_attestation.frequency
      SIGNING_KEY             = indent(6, tls_private_key.rsa-4096.private_key_pem_pkcs8)
      CBCLIENT_ANNOTATIONS    = join(",", formatlist("%s=%s", keys(local.annotations), values(local.annotations)))
  }, var.cloud_init.extra_args)

  // Firmware path depending on hardware type
  cpu_firmware = (
    var.cvm_cpu_platform.firmware != "" ? var.cvm_cpu_platform.firmware :
    var.cvm_cpu_platform.type == "snp" ? "/usr/share/ovmf/OVMF.amdsev.fd" :
    var.cvm_cpu_platform.type == "tdx" ? "/usr/share/edk2/ovmf/OVMF.inteltdx.fd" :
    try(var.cvm_cpu_platform.firmware, "Error - Firmware value malformed or not supported!")
  )

  // Libvirt launch_security config depending on hardware type
  launch_security = ({
    sevsnp = var.cvm_cpu_platform.type == "snp" ? {
      cbit_pos = 51
      policy = 196608 // 0x00030000
    } : null
    tdx = var.cvm_cpu_platform.type == "tdx" ? {
      quote_generation_service = {
        path = "/var/run/tdx-qgs/qgs.socket"
      }
    } : null
  })

  // Network configuration for IP assignment
  network_config = var.cvm_ip4 == "dhcp" ? templatefile("${path.module}/networking/dhcp.yml", {}) : templatefile("${path.module}/networking/ipv4.yml", {
    GATEWAY      = var.cvm_gateway
    IPV4_ADDRESS = var.cvm_ip4
  })

  // GiB size
  gigabyte = 1073741824 // 2^30
}
