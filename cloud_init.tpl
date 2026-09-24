#cloud-config

hostname: ${hostname}

users:
  - name: ubuntu
    groups: sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash

    ssh_authorized_keys:
      - ${ssh_key}

package_update: true

packages:
  - qemu-guest-agent
  - curl
  - wget
  - vim

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent

