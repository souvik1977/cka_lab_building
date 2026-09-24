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

# Excute below commands on all three nodes

sudo swapoff -a

sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

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


# Creating /etc/hosts

sudo tee -a /etc/hosts >/dev/null <<EOF
192.168.122.47	cp01
192.168.122.84 worker01
192.168.122.144 worker02
EOF

# Verifying entries

getent hosts cp01

getent hosts worker01

getent hosts worker02

## Installing packages on all three nodes

sudo apt-get update

sudo apt-get install -y curl gpg ca-certificates apt-transport-https

sudo install -m 0755 -d /etc/apt/keyrings

## Setting up Kubernetes version

KUBERNETES_VERSION=v1.37

CRIO_VERSION=v1.37


# Add kubernetes repository

curl -fsSL \
  "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key" \
  | sudo gpg --dearmor --yes \
  -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Add CRI-O repository

curl -fsSL \
  "https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_VERSION}/deb/Release.key" \
  | sudo gpg --dearmor --yes \
  -o /etc/apt/keyrings/cri-o-apt-keyring.gpg


echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_VERSION}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/cri-o.list


# Installing CRI-O, kubelet, kubeadm and kubectl

sudo apt-get update

sudo apt-get install -y cri-o kubelet kubeadm kubectl

# Enable and run crio

sudo systemctl enable --now crio

sudo systemctl enable kubelet



## Verify CRI-O

sudo systemctl --no-pager --full status crio

sudo crio --version

sudo kubeadm version

sudo kubelet --version

kubectl version --client


## Confirm CRI Socket

sudo test -S /var/run/crio/crio.sock && echo "CRI-O socket is available"


############# Run only on CP01 ###########

sudo kubeadm config images pull \
  --cri-socket unix:///var/run/crio/crio.sock

## Identify IPv4 Address of control plane

CONTROL_PLANE_IP=$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')
echo "$CONTROL_PLANE_IP"

## Initiate kubeadm init:

sudo kubeadm init \
  --apiserver-advertise-address="${CONTROL_PLANE_IP}" \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///var/run/crio/crio.sock \
  --node-name=cp01


### Run only on worker nodes #############

sudo kubeadm join <CONTROL_PLANE_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>


##################### Configure Kubelet on Control Node ##############

mkdir -p "$HOME/.kube"

sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"

sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

### Verify Access ###

kubectl get nodes

