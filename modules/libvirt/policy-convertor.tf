locals {
  // Build the decimal SEV-SNP policy from named settings. Each enabled flag
  // contributes its bit value. ABI versions use bits 15:8 and 7:0.
  // Bits 63:26 are omitted and therefore remain zero. Bit 17 is mandatory.
  snp_policy_from_object = var.cvm_snp_policy == null ? null : sum([
    var.cvm_snp_policy.page_swap_disable ? pow(2, 25) : 0,
    var.cvm_snp_policy.ciphertext_hiding_dram ? pow(2, 24) : 0,
    var.cvm_snp_policy.rapl_dis ? pow(2, 23) : 0,
    var.cvm_snp_policy.mem_aes_256_xts ? pow(2, 22) : 0,
    var.cvm_snp_policy.cxl_allow ? pow(2, 21) : 0,
    var.cvm_snp_policy.single_socket ? pow(2, 20) : 0,
    var.cvm_snp_policy.debug ? pow(2, 19) : 0,
    var.cvm_snp_policy.migrate_ma ? pow(2, 18) : 0,
    pow(2, 17),
    var.cvm_snp_policy.smt ? pow(2, 16) : 0,
    var.cvm_snp_policy.abi_major * pow(2, 8),
    var.cvm_snp_policy.abi_minor,
  ])
}