locals {
  // TODO: TDX is untested
  cvm_firmware = var.cvm_firmware != null ? var.cvm_firmware : var.cvm_platform == "snp" ? "/usr/share/ovmf/OVMF.amdsev.fd" : "/usr/share/edk2/ovmf/OVMF.inteltdx.fd"
  launch_security = var.cvm_platform == null ? null : {
    sevsnp = var.cvm_platform == "snp" ? {
      cbit_pos = 51
      policy   = 196608 // 0x00030000
    } : null
    tdx = var.cvm_platform == "tdx" ? {
      quote_generation_service = {
        path = "/var/run/tdx-qgs/qgs.socket"
      }
    } : null
  }
}

resource "libvirt_domain" "cvm" {
  name        = var.cvm_name
  memory      = var.cvm_ram
  memory_unit = "MiB"
  vcpu        = var.cvm_vcpus
  type        = "kvm"
  running     = true

  os = {
    type             = "hvm"
    type_arch        = "x86_64"
    type_machine     = "q35"
    loader_stateless = "yes"
    loader_readonly  = "yes"
    loader           = local.cvm_firmware
    // TODO: this should be the default when using newer versions, untested for now
    # firmware = "efi" # Needed for firmware-autoselection (libvirt >= 11.8.0)
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
