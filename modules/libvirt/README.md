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
| <a name="requirement_libvirt"></a> [libvirt](#requirement\_libvirt) | 0.9.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_http"></a> [http](#provider\_http) | n/a |
| <a name="provider_libvirt"></a> [libvirt](#provider\_libvirt) | 0.9.5 |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [libvirt_cloudinit_disk.init](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.5/docs/resources/cloudinit_disk) | resource |
| [libvirt_domain.cvm](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.5/docs/resources/domain) | resource |
| [libvirt_volume.cloudinit](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.5/docs/resources/volume) | resource |
| [libvirt_volume.overlay](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.5/docs/resources/volume) | resource |
| [local_sensitive_file.signing-key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [null_resource.signing-key-fingerprint](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [tls_private_key.rsa-4096](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [http_http.cblogin](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [libvirt_domain_interface_addresses.cvm](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.5/docs/data-sources/domain_interface_addresses) | data source |
| [local_file.signing-key-fingerprint](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cb_password"></a> [cb\_password](#input\_cb\_password) | CanaryBit password | `string` | n/a | yes |
| <a name="input_cb_username"></a> [cb\_username](#input\_cb\_username) | CanaryBit username | `string` | n/a | yes |
| <a name="input_cloud_init"></a> [cloud\_init](#input\_cloud\_init) | Custom cloud-init configuration | <pre>object({<br/>    custom_path = optional(string)<br/>    extra_args  = optional(map(any), {})<br/>  })</pre> | `{}` | no |
| <a name="input_cvm_annotations"></a> [cvm\_annotations](#input\_cvm\_annotations) | Custom annotations in "<Key>" = "<Value>" format | `map(any)` | `{}` | no |
| <a name="input_cvm_cloud_image"></a> [cvm\_cloud\_image](#input\_cvm\_cloud\_image) | Path to the CVM cloud image. The image is assumed to be already uploaded to Libvirt. | `string` | n/a | yes |
| <a name="input_cvm_cpu"></a> [cvm\_cpu](#input\_cvm\_cpu) | CPU type | `string` | `"host-passthrough"` | no |
| <a name="input_cvm_cpu_platform"></a> [cvm\_cpu\_platform](#input\_cvm\_cpu\_platform) | Type of Confidential CPU hardware platform<br/>cvm\_cpu\_platform = {<br/>  type     - CPU hardware type: ['snp', 'tdx']<br/>  firmware - (Optional) Path to custom firmware OVMF file.<br/>} | <pre>object({<br/>    type     = string<br/>    firmware = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_cvm_disk_size_gb"></a> [cvm\_disk\_size\_gb](#input\_cvm\_disk\_size\_gb) | CVM Disk size | `number` | `30` | no |
| <a name="input_cvm_gateway"></a> [cvm\_gateway](#input\_cvm\_gateway) | Default gateway for machine. Ignored if cvm\_ip4 is set to dhcp | `string` | `null` | no |
| <a name="input_cvm_ip4"></a> [cvm\_ip4](#input\_cvm\_ip4) | IP address of machine or dhcp for dynamic assignment | `string` | `"dhcp"` | no |
| <a name="input_cvm_launch_policy"></a> [cvm\_launch\_policy](#input\_cvm\_launch\_policy) | Launch security policy | `number` | `null` | no |
| <a name="input_cvm_name"></a> [cvm\_name](#input\_cvm\_name) | Confidential VM name | `string` | n/a | yes |
| <a name="input_cvm_network"></a> [cvm\_network](#input\_cvm\_network) | Libvirt network | `string` | `"default"` | no |
| <a name="input_cvm_ram"></a> [cvm\_ram](#input\_cvm\_ram) | RAM size of the machine in MB | `number` | `4096` | no |
| <a name="input_cvm_secure_boot"></a> [cvm\_secure\_boot](#input\_cvm\_secure\_boot) | Whether Secure Boot should be enabled in the firmware (yes, no). Default (not set): let libvirt decide based on the available firmware. | `bool` | `null` | no |
| <a name="input_cvm_ssh_pubkey"></a> [cvm\_ssh\_pubkey](#input\_cvm\_ssh\_pubkey) | Path to the public key used for SSH connection | `string` | `"~/.ssh/id_rsa.pub"` | no |
| <a name="input_cvm_username"></a> [cvm\_username](#input\_cvm\_username) | CVM Username for SSH login | `string` | `"tower"` | no |
| <a name="input_cvm_vcpus"></a> [cvm\_vcpus](#input\_cvm\_vcpus) | Number of vcpus (cores) | `number` | `1` | no |
| <a name="input_libvirt_pool"></a> [libvirt\_pool](#input\_libvirt\_pool) | Libvirt pool | `string` | `"default"` | no |
| <a name="input_remote_attestation"></a> [remote\_attestation](#input\_remote\_attestation) | Enable CanaryBit Remote Attestation | <pre>object({<br/>    cb_inspector_url            = optional(string, "https://api.inspector.confidentialcloud.io")<br/>    cb_inspector_client_version = optional(string, "0.1.0")<br/>    cbcli_version               = optional(string, "0.2.6")<br/>    signing_key                 = optional(string)<br/>    custom_policy_file          = optional(string)<br/>    frequency                   = optional(string, "daily")<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cvm-info"></a> [cvm-info](#output\_cvm-info) | Details of the running CVM instance(s) |
<!-- END_TF_DOCS -->
