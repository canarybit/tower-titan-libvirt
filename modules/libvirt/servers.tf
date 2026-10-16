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
    loader           = local.cvm_firmware
    loader_stateless = "yes"
    loader_readonly  = "yes"
    # firmware = "efi"   # Uncomment if you want firmware auto-selection (newer libvirt)
  }

  features = {
    acpi = true
  }

  devices = {


    hostdevs = var.cvm_gpu ? [
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
              bus      = var.gpu_bus
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

  lifecycle {
    precondition {
      condition     = !var.cvm_gpu || var.cvm_gpu_type != null
      error_message = "Set cvm_gpu_type when cvm_gpu is true."
    }
  }
}
