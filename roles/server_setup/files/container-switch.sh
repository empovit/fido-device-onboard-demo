#!/bin/bash

container_image="${1}"
current_image=$(rpm-ostree status --json | jq -r '.deployments[] | select(.booted)["container-image-reference"]')

if [ "${current_image}" != "${container_image}" ]; then
	rpm-ostree rebase "${container_image}" --experimental && reboot
else
   exit 0
fi

