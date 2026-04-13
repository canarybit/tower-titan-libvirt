locals {
  args = merge(
    {
      HOSTNAME   = var.cvm_name
      USERNAME   = var.cvm_username
      SSH_PUBKEY = file(var.cvm_ssh_pubkey)
      // CanaryBit Remote Attestation
      CB_TOKENS       = data.http.cblogin.*.response_body[0]
      CBINSPECTOR_URL = var.remote_attestation.cbinspector_url
      CBCLIENT_V      = var.remote_attestation.cbclient_version
      CBCLI_V         = var.remote_attestation.cbcli_version
      CC_ENVIRONMENTS = var.cvm_platform
      SIGNING_KEY     = indent(6, tls_private_key.rsa-4096.private_key_pem_pkcs8)
  }, var.cloud_init.extra_args)
  network_config = var.cvm_ip4 == "dhcp" ? templatefile("${path.module}/networking/dhcp.yml", {}) : templatefile("${path.module}/networking/ipv4.yml", {
    GATEWAY      = var.cvm_gateway
    IPV4_ADDRESS = var.cvm_ip4
  })
}

resource "libvirt_cloudinit_disk" "init" {
  name      = "${var.cvm_name}-cloudinit.yml"
  user_data = templatefile(var.cloud_init.custom_path != null ? var.cloud_init.custom_path : "${path.module}/../../cloud-init/attested.yml", local.args)
  meta_data = yamlencode({
    instance-id    = var.cvm_name
    local-hostname = var.cvm_name
  })
  network_config = local.network_config
}

resource "libvirt_volume" "cloudinit" {
  name = "${var.cvm_name}-cloudinit.iso"
  pool = var.pool

  create = {
    content = {
      url = libvirt_cloudinit_disk.init.path
    }
  }
}
