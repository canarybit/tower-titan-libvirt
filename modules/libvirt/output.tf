data "libvirt_domain_interface_addresses" "cvm" {
  domain = libvirt_domain.cvm.name
}

output "cvm-info" {
  description = "Details of the running CVM instance(s)"
  value       = <<-EOF

  Name:           ${libvirt_domain.cvm.name}
  Size/Family:    vCPUs: ${libvirt_domain.cvm.vcpu}, Memory: ${libvirt_domain.cvm.memory} (Confidential)
  OS:             ${libvirt_volume.overlay.backing_store.path}
  Disk:           ${libvirt_volume.overlay.capacity / local.gigabyte} GB
  Ip:             ${data.libvirt_domain_interface_addresses.cvm.interfaces[0].addrs[0].addr}
  SshEnabled:     True
  Username:       ${var.cvm_username}

  EnclaveID / Signing Key Fingerprint:
    ${data.local_file.signing-key-fingerprint.content}

  EOF
}

output "id" {
  value = libvirt_domain.cvm.id
}
