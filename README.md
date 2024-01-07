# FIDO Device Onboard (FDO) based on RHEL for Edge

This repository contains Ansible playbooks for demoing
[FIDO Device Onboard (FDO)](https://fidoalliance.org/specifications/download-iot-specifications/) using the
[Fedora IOT implementation](https://github.com/fedora-iot/fido-device-onboard-rs/) of the specification.
It relies on the official collections for [deploying FDO servers](https://github.com/ansible-collections/community.fdo)
and [building FDO-enabled installer images](https://github.com/redhat-cop/infra.osbuild).

Useful links

* [How to onboard edge devices at scale with FDO and Linux](https://www.redhat.com/sysadmin/edge-device-onboarding-fdo)

## Prerequisites

Before you begin, install Ansible dependencies and collections.

```console
ansible-galaxy install -r requirements.yml
```

## FDO Keys and Certificates

FDO servers require a number of keys and certificates. Those can be generated using the `community.fdo.generate_keys_and_certificates` role of the [Community FDO collection](https://github.com/ansible-collections/community.fdo) either locally or on a remote host.

A playbook for generating keys and certificates locally is included in this repo.

```console
ansible-playbook fdo-certs-local.yml
```

If FDO packages cannot be installed on your Ansible controller, you can generate the keys and certificates on a remote RHEL 9.x
host and copy them to local host.

```console
ansible-playbook fdo-certs-remote.yml -i <inventory>
```

The playbook expects a `certificate_generator` host group in the inventory. Example in YAML format:

```yaml
certificate_generator:
  hosts:
    rhel9:
      ansible_user: admin
      ansible_password: admin
      ansible_become_user: root
      ansible_become_pass: admin
      ansible_host: 192.168.122.24
```

## Setting up FDO Servers

You will need a host (physical or virtual machine) with RHEL 9.x and a valid RHEL subscription.

The inventory must include the following groups configured to allow privileged (Ansible `become`) access to the hosts.

* rendezvous_server
* owner_server
* manufacturing_server

The configuration must include _IP addresses_ of the hosts. Example in YAML format:

```yaml
rendezvous_server:
  hosts:
    rendezvous:
      ansible_user: admin
      ansible_password: admin
      ansible_become_user: root
      ansible_become_pass: admin
      ansible_host: 192.168.122.20
owner_server:
  hosts:
    owner:
      ansible_user: admin
      ansible_password: admin
      ansible_become_user: root
      ansible_become_pass: admin
      ansible_host: 192.168.122.21
manufacturing_server:
  hosts:
    manufacturing:
      ansible_user: admin
      ansible_password: admin
      ansible_become_user: root
      ansible_become_pass: admin
      ansible_host: 192.168.122.22
```

**Note:** You may run all FDO servers on a single host for demo purposes, in that case use the same IP address value for all `ansible_host` variables.

Passwordless `sudo` must be [configured](https://developers.redhat.com/blog/2018/08/15/how-to-enable-sudo-on-rhel#using_sudo_without_a_password) on the hosts.

Running the playbook:

```console
ansible-playbook fdo-servers.yml -i <inventory> \
  -e fdo_admin_ssh_key=<ssh_public_key> \
  -e fdo_admin_password=<password>
```

## Initializing a Device

**Important:** For this demo to work "as is" the device must support TPM, which can be also emulated in a VM.

On first boot, the device will call a manufacturing server for initialization.
There are multiple ways to specify the manufacturing server URL.

1. Add the following kernel arguments when booting the device for the first time, in the console or using kickstart (e.g. when booting via PXE):

  ```console
  fdo.manufacturing_server_url=http://<manufacturing_server>:8080 fdo.diun_pub_key_insecure=true
  ```

2. Or build an installer image that has the required FDO customizations baked in:

  ```console
  ansible-playbook fdo-image.yml -i <inventory> \
    -e download_image=true \
    -e manufacturing_server_host=<host>
  ```

  Then you can boot the device (e.g. a VM) into the installer image. Example:

  ```console
  sudo virt-install \
    --boot uefi --network default \
    --name fdo-device --memory 2048 --vcpus 2 \
    --disk size=20,path=fdo-device.qcow2 \
    --os-variant rhel9.2 \
    --tpm backend.type=emulator,backend.version=2.0,model=tpm-tis \
    --cdrom fdo-demo_edge-simplified-installer.iso
  ```

## Onboarding a Device

After the device has been initialized, it can be booted and automatically onboarded by copying
its Ownership Voucher (OV) from the manufacturing server to the owner server.

**Note**: There is no need to copy ownership vouchers if the servers run on the same host and share the filesystem.

```console
ansible-playbook sync-vouchers.yml -i <inventory>
```
