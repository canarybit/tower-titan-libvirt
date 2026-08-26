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
      <canarybit:annotations xmlns:canarybit="https://canarybit.eu/libvirt/metadata/1.0">
        %{ for k, v in local.annotations ~}
        <annotation>${k}-${v}</annotation>
        %{ endfor ~}
      </canarybit:annotations>
    EOFXML
  }

  os = {
    type             = "hvm"
    type_arch        = "x86_64"
    type_machine     = "q35"
    loader_readonly  = var.cvm_cpu_platform.type == "tdx" ? "yes" : null
    loader_stateless = "yes"
    // Prioritize explicit firmware when set
    loader   = var.cvm_cpu_platform.firmware != null ? var.cvm_cpu_platform.firmware : ""
    firmware = var.cvm_cpu_platform.firmware == null ? "efi" : null
    firmware_info = var.cvm_secure_boot == null ? null : {
      features = [
        {
          name = "secure-boot",
          enabled = var.cvm_secure_boot ? "yes" : "no"
        }
      ]
    }
  }

  features = {
    acpi = true
  }

  devices = {
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
        type  = "network"
        model = { type = "virtio" }
        source = {
          network = {
            network = var.cvm_network
          }
        }
        wait_for_ip = {}
      }
    ]
  }

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
