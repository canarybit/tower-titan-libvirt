# Libvirt Confidential VM

Terraform module to orchestrate Confidential VM (CVM) instances with Libvirt.

## Authentication

Official documentation:
https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs#example-usage

Create and source an `.rc` file with the following environment variables:
```sh
export LIBVIRT_HOST_USER="***"
export LIBVIRT_HOST_IP="***"
export LIBVIRT_DEFAULT_URI="qemu+ssh://$LIBVIRT_HOST_USER@$LIBVIRT_HOST_IP/system"
```

To simplify the ssh access use ssh-agent, like this for example:
```
eval (ssh-agent -s)
ssh-add
```
This will start a ssh-agent and add the default ssh key to it.
Specify the key used on the libvirt host if needed.

## Configuring Libvirt
Some configuration of libvirt might require additional configuration.

### AppArmor
AppArmor can sometimes interfere with libvirt, since the Terraform provider uses some custom paths.

#### Images
On ubuntu AppArmor is very strict about the location of the images and the provider places them in `/var/lib/libvirt/images`. This can result in AppArmor blocking libvirt from using the images.

To resolve this update `/etc/apparmor.d/libvirt/TEMPLATE.qemu` to include the generated paths.
```
#
# This profile is for the domain whose UUID matches this file.
#

#include <tunables/global>

profile LIBVIRT_TEMPLATE flags=(attach_disconnected) {
  #include <abstractions/libvirt-qemu>
  # Allow access to custom storage pool
  "/var/lib/libvirt/images/" r,
  "/var/lib/libvirt/images/**" rwk,
}
```

#### Permission issues with `/dev/sev`
AppArmor also blocks access to the `/dev/sev` device.

To resolve this, add the following to `/etc/apparmor.d/abstractions/libvirt-qemu`
```
/dev/sev rw
```

### Networking
Guest networking is primarly handled by libvirt.

Choose which libvirt network to use with `var.cvm_network`

`var.cvm_ip4` and `var.cvm_gateway` can be configured to pass network configuration to cloud-init. This has some assumptions:

1. Guest uses netplan v2
2. Ethernet device starts with `e`
3. Only one ethernet device is used

Some resources to why these assumptions are needed:
- https://docs.cloud-init.io/en/latest/reference/network-config-format-v2.html#network-config-v2
- https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/

### GPU passthrough

Select `var.cvm_platform.gpu.type = "nvidia"` to enable GPU passthrough and install the NVIDIA drivers in the guest. A GPU type must be selected when GPU passthrough is enabled; currently only NVIDIA GPUs are supported. By default, GPU passthrough and driver installation are disabled. Configure `var.cvm_platform.gpu.bus` for the host GPU when enabling passthrough.

```hcl
cvm_platform = {
  cpu = ...
  gpu = {
    type = "nvidia"
  }
}
```

## QEMU-agent
qemu-agent (or qemu-guest-agent), is used to report information about the vm, such as the assigned IP. The cloud-init templates in this module installs, enables and starts qemu-guest-agent.

## Confidential Firmware
Libvirt has a feature called firmware auto-selection which is able to select the correct firmware based on the type of instance. Tower integrates with this and is thus capable of finding the correct firmware automatically. Note that the firmware has to be correctly installed, which should be managed by the OVMF package from the distribution.

More information on how this works:
- https://github.com/qemu/qemu/blob/master/docs/interop/firmware.json#L469-L552
- https://libvirt.org/formatdomaincaps.html#guest-firmware

In case manual firmware selection is preferred it is possible to override the firmware with `var.cvm_cpu_platform.firmware`.

To figure out which firmware paths are available on the libvirt host run the following:
```
virsh domcapabilities --machine q35 --xpath /domainCapabilities/os/loader
```
In general any firmware with "amdsev" in the name is meant for SEV-SNP and any with "intel-tdx" is meant for TDX, but the names can vary.

### Secure Boot
If the confidential firmware also includes secure boot support, then secure boot will be enabled. Auto-selection can be influenced to select the firmware with (or without) secure boot, by setting `var.cvm_secure_boot` variable. Secure boot isn't always available and it depends on the firmware available, which is managed by the OVMF package from the distribution.

For Example:
```
/usr/share/ovmf/OVMF.amdsev.fd (no secure boot and AMD SEV-SNP)
/usr/share/ovmf/OVMF.inteltdx.ms.fd (secure boot and Intel TDX)
```

If `var.cvm_secure_boot` is set to `true` and there is no firmware with secure boot support, then the selection will fail. The same can happen in reverse if secure boot is disabled, but only secure boot firmware is available. By default the variable is set to `null`, which will then let libvirt pick the firmware with highest priority.

## Launch policies
The `cvm_launch_policy` setting controls the policy passed to the confidential VM launch-security configuration. It accepts the complete numeric policy value, for example `196608` (`0x30000`) for the default SNP policy.

For SEV-SNP, `cvm_snp_policy` provides a readable object-based alternative. The module converts its fields into the numeric policy automatically. The policy layout follows the [AMD SEV Secure Nested Paging Firmware ABI Specification (56860), page 31](https://www.amd.com/content/dam/amd/en/documents/developer/56860.pdf#page=31).

Policy selection precedence is:

1. `cvm_launch_policy`, when provided.
2. The converted `cvm_snp_policy`, for SNP guests.
3. The platform default when neither custom policy is provided.

The reserved bits `63:26` are always zero. Bit `17` is always set to one because it is required by the SNP policy specification. Bit `16` (`SMT`) defaults to one but can be explicitly disabled.

### SEV-SNP policy fields

Configure the policy:

```hcl
cvm_snp_policy = {
  page_swap_disable      = true
  ciphertext_hiding_dram = false
  rapl_dis               = false
  mem_aes_256_xts        = false
  cxl_allow              = false
  single_socket          = false
  debug                  = false
  migrate_ma             = false
  smt                    = true
  abi_major              = 0
  abi_minor              = 0
}
```

| Field | Bit(s) | Description |
|-------|--------|-------------|
| `page_swap_disable` | 25 | Disable guest access to SNP page move and swap commands when `true`. |
| `ciphertext_hiding_dram` | 24 | Require DRAM ciphertext hiding when `true`. |
| `rapl_dis` | 23 | Require Running Average Power Limit (RAPL) to be disabled when `true`. |
| `mem_aes_256_xts` | 22 | Require AES-256 XTS memory encryption when `true`; otherwise AES-128 XEX is also allowed. |
| `cxl_allow` | 21 | Allow CXL devices or memory when `true`. |
| `single_socket` | 20 | Restrict guest activation to one socket when `true`. |
| `debug` | 19 | Allow debugging when `true`; debugging is otherwise disallowed. |
| `migrate_ma` | 18 | Allow association with a migration agent when `true`. |
| `smt` | 16 | Allow SMT when `true`; defaults to `true`. |
| `abi_major` | 15:8 | Minimum ABI major version required by the guest. Must be an integer from 0 to 255. |
| `abi_minor` | 7:0 | Minimum ABI minor version required by the guest. Must be an integer from 0 to 255. |

## sev-guest in Ubuntu cloud images
`sev-guest` is not available in Ubuntu cloud images (before 25.10) without extra packages. Add the following to the cloud-init to enable it:

```yaml
runcmd:
  # Setup sev-guest (Required for ubuntu version < 25.10)
  - apt-get install linux-modules-extra-$(uname -r) -y
  - modprobe sev-guest
```

## Custom cloud-init
A custom cloud-init can be configured with the `var.cloud_init` object. `var.cloud_init.extra_args` will add template values, and can be used to replace the existing templating.

Example, use the default cloud-init instead of the attested with a new hostname:
```yaml
// custom cloud init
cloud_init = {
  custom_path = "${path.module}/../cloud-init/default.yml"
  extra_args = {
    HOSTNAME = "test-vm"
  }
}
```

The module will always supply values for these template variables if not overwritten by `var.cloud_init.extra_args`:
- HOSTNAME
- USERNAME
- SSH_PUBKEY
- CB_TOKENS
- CBINSPECTOR_URL
- CBCLIENT_V
- CBCLI_V
- CC_ENVIRONMENTS
- SIGNING_KEY

Not all values need to be templated when supplying a custom cloud-init via `var.cloud_init.custom_path`.

## Module wrappers

Users of this Terraform module can create multiple similar resources by using for_each meta-argument within module block.

Users of Terragrunt can achieve similar results by using modules provided in the wrappers directory, if they prefer to reduce amount of configuration files.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.14.0 |
| <a name="requirement_libvirt"></a> [libvirt](#requirement\_libvirt) | ~> 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_libvirt"></a> [libvirt](#provider\_libvirt) | ~> 0.9 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_commons"></a> [commons](#module\_commons) | https://canarybit-public-binaries.s3.eu-west-1.amazonaws.com/tower-commons/0.1.2/tower-commons.zip | n/a |

## Resources

| Name | Type |
|------|------|
| [libvirt_cloudinit_disk.init](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/cloudinit_disk) | resource |
| [libvirt_domain.cvm](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/domain) | resource |
| [libvirt_volume.cloudinit](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/volume) | resource |
| [libvirt_volume.overlay](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/volume) | resource |
| [libvirt_domain_interface_addresses.cvm](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/data-sources/domain_interface_addresses) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cb_password"></a> [cb\_password](#input\_cb\_password) | CanaryBit password | `string` | n/a | yes |
| <a name="input_cb_username"></a> [cb\_username](#input\_cb\_username) | CanaryBit username | `string` | n/a | yes |
| <a name="input_cloud_init"></a> [cloud\_init](#input\_cloud\_init) | Custom cloud-init configuration | <pre>object({<br/>    custom_path = optional(string)<br/>    extra_args  = optional(map(any), {})<br/>  })</pre> | `{}` | no |
| <a name="input_cvm_annotations"></a> [cvm\_annotations](#input\_cvm\_annotations) | Custom annotations in "<Key>" = "<Value>" format | `map(any)` | `{}` | no |
| <a name="input_cvm_cloud_image"></a> [cvm\_cloud\_image](#input\_cvm\_cloud\_image) | Path to the CVM cloud image. The image is assumed to be already uploaded to Libvirt. | `string` | n/a | yes |
| <a name="input_cvm_cpu"></a> [cvm\_cpu](#input\_cvm\_cpu) | CPU type | `string` | `"host-passthrough"` | no |
| <a name="input_cvm_disk_size_gb"></a> [cvm\_disk\_size\_gb](#input\_cvm\_disk\_size\_gb) | CVM Disk size | `number` | `30` | no |
| <a name="input_cvm_gateway"></a> [cvm\_gateway](#input\_cvm\_gateway) | Default gateway for machine. Ignored if cvm\_ip4 is set to dhcp | `string` | `null` | no |
| <a name="input_cvm_ip4"></a> [cvm\_ip4](#input\_cvm\_ip4) | IP address of machine or dhcp for dynamic assignment | `string` | `"dhcp"` | no |
| <a name="input_cvm_launch_policy"></a> [cvm\_launch\_policy](#input\_cvm\_launch\_policy) | Launch security policy | `number` | `null` | no |
| <a name="input_cvm_name"></a> [cvm\_name](#input\_cvm\_name) | Confidential VM name | `string` | n/a | yes |
| <a name="input_cvm_network"></a> [cvm\_network](#input\_cvm\_network) | Libvirt network | `string` | `"default"` | no |
| <a name="input_cvm_platform"></a> [cvm\_platform](#input\_cvm\_platform) | Type of Confidential CPU hardware platform<br/>cvm\_platform = {<br/>  cpu = {<br/>    type     - CPU hardware type: ['snp', 'tdx']<br/>    firmware - (Optional) Path to custom firmware OVMF file.<br/>  }<br/>  gpu = {<br/>    type            - GPU provider: ['nvidia']<br/>    bus             - domain:bus:device.function can be fetched with `lspci | grep -i nvidia'<br/>    driver_version  - Version of the driver to install, the default depends on GPU provider<br/>  }<br/>}<br/>` | <pre>object({<br/>    cpu = object({<br/>      type     = string<br/>      firmware = optional(string)<br/>    })<br/>    gpu = optional(object({<br/>      type = string<br/>      bus  = optional(number, 2)<br/>      driver_version = optional(number)<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_cvm_ram"></a> [cvm\_ram](#input\_cvm\_ram) | RAM size of the machine in MB | `number` | `4096` | no |
| <a name="input_cvm_secure_boot"></a> [cvm\_secure\_boot](#input\_cvm\_secure\_boot) | Whether Secure Boot should be enabled in the firmware (yes, no). Default (not set): let libvirt decide based on the available firmware. | `bool` | `null` | no |
| <a name="input_cvm_snp_policy"></a> [cvm\_snp\_policy](#input\_cvm\_snp\_policy) | Optional SEV-SNP guest policy settings | <pre>object({<br/>    page_swap_disable      = optional(bool, false)<br/>    ciphertext_hiding_dram = optional(bool, false)<br/>    rapl_dis               = optional(bool, false)<br/>    mem_aes_256_xts        = optional(bool, false)<br/>    cxl_allow              = optional(bool, false)<br/>    single_socket          = optional(bool, false)<br/>    debug                  = optional(bool, false)<br/>    migrate_ma             = optional(bool, false)<br/>    smt                    = optional(bool, true)<br/>    abi_major              = optional(number, 0)<br/>    abi_minor              = optional(number, 0)<br/>  })</pre> | `null` | no |
| <a name="input_cvm_ssh_pubkey"></a> [cvm\_ssh\_pubkey](#input\_cvm\_ssh\_pubkey) | Path to the public key used for SSH connection | `string` | `"~/.ssh/id_rsa.pub"` | no |
| <a name="input_cvm_username"></a> [cvm\_username](#input\_cvm\_username) | CVM Username for SSH login | `string` | `"tower"` | no |
| <a name="input_cvm_vcpus"></a> [cvm\_vcpus](#input\_cvm\_vcpus) | Number of vcpus (cores) | `number` | `1` | no |
| <a name="input_libvirt_pool"></a> [libvirt\_pool](#input\_libvirt\_pool) | Libvirt pool | `string` | `"default"` | no |
| <a name="input_remote_attestation"></a> [remote\_attestation](#input\_remote\_attestation) | Enable CanaryBit Remote Attestation | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cvm-info"></a> [cvm-info](#output\_cvm-info) | Details of the running CVM instance(s) |
<!-- END_TF_DOCS -->
