resource "libvirt_domain" "cvm" {
  name        = var.cvm_name
  memory      = var.cvm_ram
  memory_unit = "MiB"
  vcpu        = var.cvm_vcpus
  type        = "kvm"
  running     = true

  // Annotations
  metadata = {
    xml = <<EOFXML
      <canarybit:annotations xmlns:canarybit="canarybit.eu">
        <annotation>canarybit-tower</annotation>
        <annotation>enclaveid-${substr(module.commons.enclave_id, 0, 8)}</annotation>
      </canarybit:annotations>
      %{for k, v in var.cvm_annotations~}
      <custom:annotations xmlns:custom="custom">
        <annotation>${k}-${v}</annotation>
      </custom:annotations>
      %{endfor~}
    EOFXML
  }

  os = {
    type             = "hvm"
    type_arch        = "x86_64"
    type_machine     = "q35"
    loader_readonly  = "yes"
    loader_stateless = "yes"
    // Prioritize explicit firmware when set
    loader   = var.cvm_platform.cpu.firmware != null ? var.cvm_platform.cpu.firmware : ""
    firmware = var.cvm_platform.cpu.firmware == null ? "efi" : null
    firmware_info = var.cvm_secure_boot == null ? null : {
      features = [
        {
          name    = "secure-boot",
          enabled = var.cvm_secure_boot ? "yes" : "no"
        }
      ]
    }
  }

  features = {
    acpi = true
  }

  devices = {
    hostdevs = var.cvm_platform.gpu != null ? [
      {
        mode    = "subsystem"
        type    = "pci"
        managed = true

        subsys_pci = {
          driver = {
            name = "vfio"
          }
          source = {
            address = {
              domain   = 0
              bus      = var.cvm_platform.gpu.bus
              slot     = 0
              function = 0
            }
          }
          address = {
            type = "pci"
            bus  = 10
          }
        }
      }
    ] : []
    controllers = [
      {
        type  = "scsi"
        model = "virtio-scsi"
      }
    ]
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.overlay.pool
            volume = libvirt_volume.overlay.name
          }
        }
        target = {
          dev = "sda"
          bus = "scsi"
        }
        driver = {
          type = "qcow2"
        }
        boot = {
          order = 1
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.cloudinit.pool
            volume = libvirt_volume.cloudinit.name
          }
        }
        target = {
          bus = "scsi"
          dev = "sdb"
        }
      }
    ]

    interfaces = [
      {
        type = "network"
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = var.cvm_network
          }
        }
        wait_for_ip = {}
      }
    ]
  }

  # These are now valid top-level blocks/arguments in v0.9+
  memory_backing = {
    memory_access = {
      mode = "shared"
    }
    memory_source = {
      type = "memfd"
    }
  }
  cpu = {
    mode  = var.cvm_cpu
    check = "none"
  }

  launch_security = local.launch_security

  destroy = {
    undefine = true
  }
}
