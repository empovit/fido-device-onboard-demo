# FIDO Device Onboard (FDO) based on RHEL for Edge

This repository contains Ansible playbooks for setting up a [FIDO Device Onboard (FDO)](https://fidoalliance.org/specifications/download-iot-specifications/) environment, using the [Fedora IOT implementation](https://github.com/fedora-iot/fido-device-onboard-rs/) of the FDO specification.

As part of device onboarding, the operating system (OS) used for FDO initialization is replaced by an [OS distributed as a container image](https://coreos.github.io/rpm-ostree/container/).

Useful links

* [How to onboard edge devices at scale with FDO and Linux](https://www.redhat.com/sysadmin/edge-device-onboarding-fdo)
* [RHEL for Edge Image builder demo](https://github.com/kwozyman/rhel-edge-demo/tree/containers#readme)

## Setting up servers

You will need machines (physical or virtual) with an operating system that provides the `fdo-*` packages (`fdo-admin-cli` etc.), e.g. RHEL 9.x.

```
ansible-playbook fdo-servers.yml -i inventory.yml -e admin_ssh_key_file=~/.ssh/id_ed25519.pub
```

The `inventory.yml` must contain the following hosts:

* keys-generator
* manufacturing
* owner-onboarding
* rendezvous
* serviceinfo-api

You can use the same machine to run multiple components of the FDO setup by pointing the corresponding host roles to the same Ansible host in the inventory. Example:

```
    manufacturing:
      ansible_user: root
      ansible_host: 192.168.122.204
    owner-onboarding:
      ansible_user: root
      ansible_host: 192.168.122.204
    <and so on>
```

### Key generation in a container

If you want to use your local machine to generate FDO keys and certificates, but `fdo-admin-tool` is not available for your system, use a container.

Start a container as follows

```
podman run --rm -d --entrypoint /usr/bin/sleep --name keys-generator rockylinux:9 infinity
```

and then add it to the inventory with a [podman connection](https://docs.ansible.com/ansible/latest/collections/containers/podman/podman_connection.html) as follows:

```
    keys-generator:
      ansible_connection: containers.podman.podman
      ansible_host: "{{ inventory_hostname }}"
      ansible_user: root
```

## Building a RHEL for Edge image

You will need a RHEL 9.x machine to build a simplified RHEL for Edge installer image. Add the host to the inventory as an `image-builder`, e.g.:

```
    image-builder:
      ansible_user: root
      ansible_host: 192.168.122.204
```

Run the `image.yml` playbook. Optionally, the resulting image will be downloaded to you local (Ansible controller) host.

```
ansible-playbook image.yml -i inventory.yml -e root_ssh_key_file=~/.ssh/id_ed25519.pub -e admin_password=<password> [-e download_image=true]
```

By default, an FDO image built by the playbook will use the IPv4 address of a `manufacturing` host in the inventory. You can override this with `-e manufacturing_server=<host>`.

## Building an OS container image

**NOTICE:** For simplicity and performance, the OS container image will be built with the same playbook, and on top of the same RHEL for Edge base image as the FDO image. Also, it will be made available through a container image registry on the image builder machine. In real life though, the FDO image belongs in manufacturing while the OS container image belongs in owner onboarding. That is, it is likely to be used to run a custom OS after a device has been onboarded by FDO.

## Initializing a device

The image built in the previous step (`<id>-simplified-installer.iso`) can now be used to boot a device for device initialization.

For example, a KVM virtual machine:

```
sudo virt-install \
    --boot uefi --network default \
    --name fdo-device-vm --memory 2048 --vcpus 2 \
    --disk size=20,path=fdo-device-vm.qcow2 \
    --cdrom <id>-simplified-installer.iso \
    --os-variant rhel9.0 --tpm backend.type=emulator,backend.version=2.0,model=tpm-tis
```

## Onboarding a device

After the device has been initialized, it can be onboarded by copying its Ownership Voucher (OV) from the _/root/fdo/manufacturing_server/owner_vouchers_ directory on the `manufacturing` server to the _/root/fdo/owner_onboarding_server/owner_vouchers_ directory on the `owner-onboarding` server.

This can be done either manually, or by running

```
ansible-playbook sync-ownership-vouchers.yml -i inventory.yml
```

## Troubleshooting

If you get low on the disk space, clean up osbuild temporary artifacts.

```
/var/lib/osbuild-composer/artifacts/
/var/cache/osbuild-worker/osbuild-store/tmp/
/var/cache/osbuild-worker/osbuild-store/sources/org.osbuild.files/
```

Also, find and delete unnecessary large files, e.g.

```
find / -type f -size +100M 2> /dev/null
```

