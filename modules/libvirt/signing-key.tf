# RSA key of size 4096 bits
 resource "tls_private_key" "rsa-4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "signing-key" {
  content = tls_private_key.rsa-4096.private_key_pem_pkcs8
  filename = "${path.cwd}/output/${var.cvm_name}/signing-key.pem"
}

resource "null_resource" "signing-key-fingerprint" {
  provisioner "local-exec" {
    command = "openssl rsa -in ${local_sensitive_file.signing-key.filename} -pubout -outform DER | sha256sum > ${path.cwd}/output/${var.cvm_name}/signing-key-fingerprint.txt"
  }
  depends_on = [ tls_private_key.rsa-4096 ]
}

data "local_file" "signing-key-fingerprint" {
   filename = "${path.cwd}/output/${var.cvm_name}/signing-key-fingerprint.txt"
   depends_on = [null_resource.signing-key-fingerprint]
}
