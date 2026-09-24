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


# Step-9
# Configuring Cluster

sudo swapoff -a

# Install Packages

sudo apt-get install containerd kubelet kubeadm kubectl 

# Configuring

sudo kubeadm init \
--pod-network-cidr=192.168.0.0/16

# Creting modules to load

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay

sudo modprobe br_netfilter

# Creating Kernel Configuration file

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv6.ip_forward = 1
EOF

sudo sysctl --system


