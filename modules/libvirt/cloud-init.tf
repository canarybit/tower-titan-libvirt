resource "libvirt_cloudinit_disk" "init" {
  name      = "${var.cvm_name}-cloudinit.yml"
  user_data = module.commons.cloud_init_user_data
  meta_data = yamlencode({
    instance-id    = var.cvm_name
    local-hostname = var.cvm_name
  })
  network_config = local.network_config
}

resource "libvirt_volume" "cloudinit" {
  name = "${var.cvm_name}-cloudinit.iso"
  pool = var.libvirt_pool

  create = {
    content = {
      url = libvirt_cloudinit_disk.init.path
    }
  }
}
