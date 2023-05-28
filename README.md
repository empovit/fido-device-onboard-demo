# FIDO Device Onboard (FDO) based on RHEL for Edge

This repository contains Ansible playbooks for demoing
[FIDO Device Onboard (FDO)](https://fidoalliance.org/specifications/download-iot-specifications/) using the
[Fedora IOT implementation](https://github.com/fedora-iot/fido-device-onboard-rs/) of the specification.
It relies on the official collections for [deploying FDO servers](https://github.com/ansible-collections/community.fdo)
and [building FDO-enabled installer images](https://github.com/redhat-cop/infra.osbuild).

Useful links

* [How to onboard edge devices at scale with FDO and Linux](https://www.redhat.com/sysadmin/edge-device-onboarding-fdo)

## Setting up FDO Servers

You will need a machine (physical or virtual) with RHEL 9.x and a valid RHEL subscription.

```console
ansible-playbook fdo-servers.yml -i <inventory> \
  -e serviceinfo_api_server_service_info_initial_user_sshkeys=<ssh_public_key> \
  -e manufacturing_server_rendezvous_info_ip_address=<ip_address> \
  -e owner_onboarding_server_owner_addresses_ip_address=<ip_address>
```

The inventory must contain the following groups, configured to allow privileged (Ansible `become`) access to the hosts:

* rendezvous_server
* owner_server
* manufacturing_server

Password-less sudo must be configured on the hosts.

## Initializing a Device

The device must support TPM (can be emulated in a VM).

Boot into a RHEL for Edge disk image that has the following customizations

```toml
[customizations.fdo]
manufacturing_server_url = "http://<manufacturing_server_ip>:8080"
diun_pub_key_insecure = "true"
```

or add the following kernel arguments when booting

```console
fdo.manufacturing_server_url=http://<manufacturing_server_ip>:8080 fdo.diun_pub_key_insecure=true
```

## Building an FDO-enabled Installer Image

Alternatively, you can build a simplified RHEL for Edge installer image that already includes the FDO customizations.

```console
ansible-playbook fdo-image.yml -i <inventory> -e download_image=true -e blueprint_name=fdo
```

You can change the installation device via

```console
-e installation_device=/dev/sda
```

## Onboarding a Device

After the device has been initialized, it can be onboarded by copying its Ownership Voucher (OV) from the manufacturing server to the owner server.

**Note**: This is not needed if the servers run on the same machine and share the filesystem.

```console
ansible-playbook sync-vouchers.yml -i <inventory>
```
