module "commons" {
  source = "https://canarybit-public-binaries.s3.eu-west-1.amazonaws.com/tower-commons/v0.1.0/tower-commons.zip"

  cb_username = var.cb_username
  cb_password = var.cb_password

  cvm_name     = var.cvm_name
  cvm_username = var.cvm_username
  cvm_platform = var.cvm_platform.cpu.type

  cvm_annotations = var.cvm_annotations

  remote_attestation = merge(var.remote_attestation, local.client_annotations)
  cloud_init_packages = concat([
    "qemu-guest-agent"
    ],
    var.cvm_platform.gpu != null && var.cvm_platform.gpu.type == "nvidia" ?
    [
      "nvidia-driver-${local.gpu_driver_version}-open",
      "nvidia-utils-${local.gpu_driver_version}"
    ] : []
  )
  cloud_init = var.cloud_init
}
