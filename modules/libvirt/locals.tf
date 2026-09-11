locals {
  // cloud-init config template
  cloud_init_args = merge(
    {
      HOSTNAME   = var.cvm_name
      USERNAME   = var.cvm_username
      SSH_PUBKEY = file(var.cvm_ssh_pubkey)
      // CanaryBit Remote Attestation
      CB_TOKENS                       = data.http.cblogin.*.response_body[0]
      CB_INSPECTOR_URL                 = var.remote_attestation.cb_inspector_url
      CB_INSPECTOR_CLIENT_V           = var.remote_attestation.cb_inspector_client_version
      CBCLI_V                         = var.remote_attestation.cbcli_version
      ENVIRONMENTS                    = var.cvm_cpu_platform.type
      CUSTOM_POLICY_OPT               = var.remote_attestation.custom_policy_file != null ? "--policy /etc/canarybit/custom-policy.rego" : ""
      CUSTOM_POLICY                   = var.remote_attestation.custom_policy_file != null ? indent(6, file(var.remote_attestation.custom_policy_file)) : ""
      FREQUENCY                       = var.remote_attestation.frequency
      SIGNING_KEY                     = indent(6, tls_private_key.rsa-4096.private_key_pem_pkcs8)
      CB_INSPECTOR_CLIENT_ANNOTATIONS = join(",",
        [for k,v in var.cvm_annotations : "${k}=${v}"],
        ["canarybit.eu/provisioner=tower"],
        ["canarybit.eu/resource=cvm"],
        ["canarybit.eu/platform=libvirt"],
      )
    },
    var.cloud_init.extra_args
  )

  launch_policy_defaults = {
    snp = 196608
    tdx = 268435456
  }

  launch_security_policy = coalesce(var.cvm_launch_policy, local.launch_policy_defaults[var.cvm_cpu_platform.type])

  // Libvirt launch_security config depending on hardware type
  launch_security = ({
    sevsnp = var.cvm_cpu_platform.type == "snp" ? {
      cbit_pos = 51
      policy   = local.launch_security_policy
    } : null
    tdx = var.cvm_cpu_platform.type == "tdx" ? {
      policy = local.launch_security_policy
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
