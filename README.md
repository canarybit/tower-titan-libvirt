# CanaryBit Tower Public Libvirt

CanaryBit [Tower](https://www.canarybit.eu/confidential-cloud-tower/) is a security orchestration tool to provision, control and maintain Confidential VM instances.

Tower integrates with a long list of Cloud Service Providers (CSPs), private and bare-metal infrastructure to provide 
governance of the resources defining your Trusted Execution Environment (TEE).

This repository contains these modules:
- [Libvirt/Qemu](https://libvirt.org/)

For the CSP modules see [Tower](https://registry.terraform.io/modules/canarybit/tower/canarybit/latest)

It implements Infrastructure-as-Code (IaC) and SecDevOps best-practices to provide integrity and state-of-the-art security to your workloads runtime.

## Requirements

- [Terraform](https://developer.hashicorp.com/terraform) or [OpenTofu](https://opentofu.org/docs/intro/install/) installed;
- Credentials to access your Infrastructure provider (either Public Cloud or On-prem);
- A CanaryBit account. (*New user? [Create an account.](https://canarybit-production.auth.eu-north-1.amazoncognito.com/login?client_id=54g4h9tpulnnkmhivgn5nipjki&redirect_uri=https://docs.confidentialcloud.io/&response_type=code&scope=email+openid+profile)*)

## Documentation
For setup instructions, API references, and usage examples, read the [CanaryBit Tower Technical Documentation](https://docs.confidentialcloud.io/tower/).

Setup instructions and documentation specific to the modules is available in the readme of the modules.

## Integrations

- **Galaxy server**: Support for the [Galaxy project](https://github.com/galaxyproject) for data-intensive computation.

## Contacts

Reach us out at [hi@canarybit.eu](mailto:hi@canarybit.eu) for more information.

/ The CanaryBit Team
