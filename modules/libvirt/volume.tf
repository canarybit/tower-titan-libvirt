resource "libvirt_volume" "overlay" {
  name     = "${var.cvm_name}-disk.qcow2"
  pool     = var.pool
  capacity = var.cvm_disk_size_gb * local.gigabyte

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = var.cloud_image_id
    format = {
      type = "qcow2"
    }
  }
}
