resource "libvirt_volume" "overlay" {
  name     = "${var.cvm_name}-disk.qcow2"
  pool     = var.libvirt_pool
  capacity = var.cvm_disk_size_gb * local.gigabyte

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = var.cvm_cloud_image
    format = {
      type = "qcow2"
    }
  }
}
