# Step-1

lsmod | grep kvm

systemctl status libvirtd

sudo systemctl enable --now libvirtd

virsh list --all

# Step-2

sudo dnf config-manager --add-repo \
https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

sudo dnf install terraform -y

terraform version

# Step-3

sudo mkdir -p /var/lib/libvirt/images

cd /var/lib/libvirt/images

wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Step-4

ssh-keygen -t ed25519

cat ~/.ssh/id_ed25519.pub

# Step-5

mkdir ~/cka-lab

cd ~/cka-lab

cka-lab/

main.tf

variables.tf

cloud_init.tpl

# Step-6

terraform validate

terraform apply

# Step-7
# Find IP Adresses

virsh domifaddr cp01

virsh domifaddr worker01

virsh domifaddr worker02

or

virsh net-dhcp-leases default

# Step-8 Connecting to VM

ssh ubuntu@192.168.122.101




## Deleting VM's and Releasing unused IP addresses:

terraform destroy

[Incase you deleted tfstate]

virsh net-dhcp-leases default

virsh destroy cp01

virsh undefine cp01 --remove-all-storage

virsh destroy worker01

virsh undefine worker01 --remove-all-storage

virsh destroy worker02

virsh undefine worker02 --remove-all-storage

virsh net-dhcp-leases default

dhcp_release virbr0 192.168.122.106 52:54:00:3e:70:e5 [Repeat same steps for other nodes]

