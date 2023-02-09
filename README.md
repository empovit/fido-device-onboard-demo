# FIDO Device Onboard (FDO) based on RHEL for Edge

This repository contains Ansible playbooks for setting up a [FIDO Device Onboard (FDO)](https://fidoalliance.org/specifications/download-iot-specifications/) environment, using the [Fedora IOT implementation](https://github.com/fedora-iot/fido-device-onboard-rs/) of the FDO specification and the [Ansible community collection for FDO](https://github.com/ansible-collections/community.fdo).

Useful links

* [How to onboard edge devices at scale with FDO and Linux](https://www.redhat.com/sysadmin/edge-device-onboarding-fdo)

## Setting up servers

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

Password-less sudo must be configured on the hosts, and they must be able to talk to each other via SSH.

## Initializing a device

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


## Onboarding a device

After the device has been initialized, it can be onboarded by copying its Ownership Voucher (OV) from the manufacturing server to the owner server.

**Note**: This is not needed if the servers run on the same machine and share the filesystem.

```console
ansible-playbook sync-vouchers.yml -i <inventory>
```
