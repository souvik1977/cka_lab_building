## Set hostname [All Nodes]
[Control Node]

sudo hostnamectl set-hostname cp01.lab.example.com

sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg <<EOF
preserve_hostname: true
fqdn: cp01.lab.example.com
hostname: cp01
create_hostname_file: true
EOF

sudo cloud-init clean

sudo grep -R preserve_hostname /etc/cloud


[worker01]

sudo hostnamectl set-hostname worker01.lab.example.com

sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg <<EOF
preserve_hostname: true
fqdn: worker01.lab.example.com
hostname: worker01
create_hostname_file: true
EOF

sudo cloud-init clean

sudo grep -R preserve_hostname /etc/cloud


[worker02]

sudo hostnamectl set-hostname worker02.lab.example.com

sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg <<EOF
preserve_hostname: true
fqdn: worker02.lab.example.com
hostname: worker02
create_hostname_file: true
EOF

sudo cloud-init clean

sudo grep -R preserve_hostname /etc/cloud


## Swap-Off [All Nodes]
sudo swapoff -a
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

## Importing Kernel Modules [All Nodes]
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter


## Kernel Configurations [All Nodes]

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf 
net.bridge.bridge-nf-call-iptables = 1 
net.bridge.bridge-nf-call-ip6tables = 1 
net.ipv4.ip_forward = 1 
net.ipv6.ip_forward = 1 
EOF

sudo sysctl --system

## Update /etc/hosts [All Nodes]

sudo sh -c 'cat >> /etc/hosts <<EOF 
192.168.122.4 cp01.lab.example.com cp01
192.168.122.214 worker01.lab.example.com worker01
192.168.122.147 worker02.lab.example.com worker02 
EOF'

sudo sed -i 's|192.168.122.190|192.168.122.4|g' /etc/hosts
sudo sed -i 's|192.168.122.137|192.168.122.214|g' /etc/hosts
sudo sed -i 's|192.168.122.106|192.168.122.147|g' /etc/hosts

### Checking hosts entries:
getent hosts cp01

getent hosts worker01

getent hosts worker02


## Installing Packages [All Nodes]

sudo apt-get update

sudo apt-get install -y curl gpg ca-certificates apt-transport-https

sudo install -m 0755 -d /etc/apt/keyrings


## Setting up Kubernetes Version [All Nodes]
export KUBERNETES_VERSION=v1.36 

[ #later we will upgrade from 1.36 -> 1.37 and from 1.37.x -> 1.37.y]

## Adding Kubernetes Repositories [All Nodes]

curl -fsSL \
"https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key" \
| sudo gpg --dearmor --yes \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list

## Installing CRI-O [Optional] [All Nodes] - Applicable only if you do not want to go with containerd

export CRIO_VERSION=v1.36 

[We will keep this as 1.36 to perform upgrade to 1.37]

curl -fsSL \
"https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_VERSION}/deb/Release.key" \
| sudo gpg --dearmor --yes \
-o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_VERSION}/deb/ /" \
| sudo tee /etc/apt/sources.list.d/cri-o.list


## Installing kubelet, kubeadm, kubectl, [cri-o] [All Nodes]

sudo apt-get update && \
sudo apt-get install -y kubelet kubeadm kubectl

apt-mark hold kubelet kubeadm kubectl

### [Optional]
sudo apt-get install -y crio-o


## Install and Configure containerd [All Nodes]

sudo apt install -y containerd

sudo mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml

### Enable cgroup for containerd:

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

## Starting Containerd [All Nodes]

sudo systemctl restart containerd && \
sudo systemctl enable containerd && \
sudo systemctl status containerd


## On Controle Node:
CONTROL_PLANE_IP=$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')
echo "$CONTROL_PLANE_IP"

### Generating a config file:

sudo kubeadm config print init-defaults > config.yml

sed -i 's|kubernetesVersion: 1.36.0|kubernetesVersion: v1.36.0|g' config.yml

sed -i 's|advertiseAddress: 1.2.3.4|advertiseAddress: 192.168.122.4|g' config.yml

sed -i 's|name: node|name: cp01|g' config.yml

sed -i 's|clusterName: kubernetes|clusterName: dev.k8s.cluster|g' config.yml

sed -i '/kind: ClusterConfiguration/a controlPlaneEndpoint: cp01.lab.example.com:6443' config.yml

sed -i 's|serviceSubnet: 10.96.0.0/12|serviceSubnet: 10.96.0.0/12\n  podSubnet: "10.240.0.0/16"|g' config.yml

sed -i 's|dnsDomain: cluster.local|dnsDomain: lab.example.com|g' config.yml

sed -i 's|podSubnet: "10.240.0.0/16"|podSubnet: 10.240.0.0/16|g' config.yml

## As needed:
sed -i 's|controlPlaneEndpoint: "cp01.lab.example.com:6443"|controlPlaneEndpoint: cp01.lab.example.com:6443|g' config.yml

## Initiate Kubeadm:

sudo kubeadm init
--apiserver-advertise-address="${CONTROL_PLANE_IP}"
--pod-network-cidr=10.244.0.0/16
--cri-socket=unix:///var/run/crio/crio.sock
--node-name=cp01


#### Using config file:

sudo kubeadm init --config config.yml 


## Configuring kubectl [Control Node]:
mkdir -p $HOME/.kube && \
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config

## Autocomplete the profile

cp ~/.bashrc ~/.bashrc.bkp

source <(kubectl completion bash)

echo "source <(kubectl completion bash)" >> ~/.bashrc

echo "complete -o default -F __start_kubectl k" >> ~/.bashrc

source ~/.bashrc



## Installing Calico manifests files [Control Plane]:

wget -4 -O calico.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml

wget -4 -O custom-resources.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml

sed -i 's|cidr: 192.168.0.0/16|cidr: 10.240.0.0/16|g' custom-resources.yaml


kubectl create -f calico.yaml

kubectl create -f custom-resources.yaml

kubectl get pods -n calico-system


### Troubleshooting: 
##### Error:
error: error execution phase preflight: couldn't validate the identity of the API Server: invalid discovery token CA certificate hash: invalid hash "sha256:d8c5d7addc2653cd90822be6145c9091157faf63ac15d6b98277", expected a 32 byte SHA-256 hash, found 26 bytes
To see the stack trace of this error execute with --v=5 or higher

#### Fix:
sudo kubeadm token create --print-join-command


## Installing crictl on the control-plane 

CRICTL_VERSION="v1.36.0"

wget https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz

sudo tar zxvf crictl-${CRICTL_VERSION}-linux-amd64.tar.gz -C /usr/local/bin

crictl --version


## Test manually:

sudo ss -xl | grep containerd

sudo crictl \
--runtime-endpoint unix:///run/containerd/containerd.sock \
info


## Configuring crictl to use containerd 

sudo tee /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF



## Testing:

sudo crictl ps -a


## Adding Worker Nodes:
sudo kubeadm token create --print-join-command

sudo kubeadm join cp01.lab.example.com:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:d8c5d7addc2653cd90822be6145c9091157faf63ac15d6b9827747cf65382af3

#### Spin up a temporary test pod

kubectl run busybox --image=busybox --restart=Never -- sleep 3600

#### Verify it gets an IP from your 10.240.x.x pool

kubectl get pod busybox -o wide

#### Test internal CoreDNS lookup via your custom 'lab.example.com' suffix

kubectl exec -it busybox -- nslookup kubernetes.default.svc.lab.example.com



## Troubleshooting:

#### Node not ready

sudo journalctl -u kubelet -n 100 --no-pager

sudo journalctl -u containerd -n 50 --no-pager

#### Check Certificate if generated with correct hostname [all three nodes]:
sudo openssl x509 \
-in /var/lib/kubelet/pki/kubelet-client-current.pem \
-noout -subject

### Check if hostnames are correctly reflecting

hostname

sudo hostnamectl set-hostname <hostname>


## Installing Metrics-Server 

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl get pods -n kube-system 

[it should show 0/1 pods]

kubectl -n kube-system logs metrics-server<TAB>

[it should show that certificate verification is failing]

#### Check current arguments

kubectl get deployment metrics-server \
-n kube-system \
-o=jsonpath='{.spec.template.spec.containers[0].args}'


#### Patch the deployment

kubectl patch deployment metrics-server \
-n kube-system \
--type='json' \
-p='[
  {
    "op":"add",
    "path":"/spec/template/spec/containers/0/args/-",
    "value":"--kubelet-insecure-tls"
  }
]'


#### Verify:

kubectl get deployment metrics-server \
-n kube-system \
-o yaml | grep kubelet-insecure-tls



## ETCD - Backup and restoration Process 

### ETCD - Backup Process 

#### Step-1: Install etcd-cliet [Controller node]

sudo apt install etcd-client 

#### Step-2: Verify if etcdctl version:

etcdctl version 

etcdctl --help 

etcdctl snapshot save --help

###### If your etcdctl version is 2 then do below

sudo ETCDCTL_API=3 etcdctl snapshot save --help

#### Step-3 Find out details

ps aux | grep etcd 

Path="/etc/kubernetes/pki/etcd"
CA Certificate="ca.crt"
Server certificate File="server.crt"
Server certificate Key file="server.key"

#### Step-4 Checking if etcdctl is able to connect to etcd-Server

sudo etcdctl get / --keys-only=true --prefix --endpoints=localhost:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key


###### Performs health-Check

sudo ETCDCTL_API=3 etcdctl \
 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
 --cert=/etc/kubernetes/pki/etcd/server.crt \
 --key=/etc/kubernetes/pki/etcd/server.key \
 endpoint health

#### Step-5 Taking Snapshot

sudo etcdctl \
--endpoints=localhost:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
snapshot save /opt/etcd-backup/etcd-backup.db

#### Step-6 Checking snapshot status 

sudo etcdctl --write-out=table snapshot status /opt/etcd-backup/etcd-backup.db

#### Step-7 Creating copy of the backup file 

sudo cp /opt/etcd-backup/etcd-backup.db /opt/etcd-backup/etcd-backup.db.2



### ETCD - Restore

#### Step-1 Restore the database to /var/lib/etcd-restore

sudo etcdctl snapshot restore /opt/etcd-backup/etcd-backup.db --data-dir /var/lib/etcd-restore 

sudo vim /etc/kubernetes/manifests/etcd.yaml 

spec:
  containers:
  - command:
   - --data-dir=/var/lib/etcd-restore   #from /var/lib/etcd
  volumes:
  - hostPath:
      path: /var/lib/etcd-restore   #from /var/lib/etcd
	  

sudo sed -i 's#--data-dir=/var/lib/etcd#--data-dir=/var/lib/etcd-restore#g' \
/etc/kubernetes/manifests/etcd.yaml

sudo sed -i 's#path: /var/lib/etcd#path: /var/lib/etcd-restore#g' \
/etc/kubernetes/manifests/etcd.yaml

grep -E 'data-dir|path: /var/lib/etcd' \
/etc/kubernetes/manifests/etcd.yaml


watch sudo crictl ps | grep etcd

sudo crictl logs $(sudo crictl ps -a | grep etcd | head -1 | awk '{print $1}')

kubectl get nodes


#### Step-2 Check health of the etcd 

sudo etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

sudo systemctl start kubelet

###### Troubleshooting if your existing admin is unable to connect to API Server:

kubectl auth can-i list nodes

[expected 'No' ]

sudo kubectl \
  --kubeconfig=/etc/kubernetes/super-admin.conf \
  create clusterrolebinding kubeadm-cluster-admins \
  --clusterrole=cluster-admin \
  --group=kubeadm:cluster-admins

[Restart kubelet on all nodes]

sudo systemctl restart kubelet 


#### Fix labels
kubectl label node cp01 \
  node-role.kubernetes.io/control-plane="" --overwrite
  
kubectl label node worker01.lab.example.com \
  node-role.kubernetes.io/worker-node=worker --overwrite

kubectl label node worker02.lab.example.com \
  node-role.kubernetes.io/worker-node=worker --overwrite

#### Fix if your coredns and kube-proxy disappeared post etcd restoration

sudo kubeadm init phase addon coredns

sudo kubeadm init phase addon kube-proxy


## Kubernetes Cluste Upgrade process 

### Step-1: Upgrade Primary Control Plane 

#### Changing the repository on the control Node

##### [a] Print the current repository contents: 

pager /etc/apt/sources.list.d/kubernetes.list

##### [b] Modify the version from "v1.36" to "v1.37"

From - https://pkgs.k8s.io/core:/stable:/v1.36/deb/

To - https://pkgs.k8s.io/core:/stable:/v1.37/deb/

sudo sed -i 's|v1.36|v1.37|g' /etc/apt/sources.list.d/kubernetes.list

##### [c] Check once again it shoud show you 1.37

pager /etc/apt/sources.list.d/kubernetes.list

Expected output: https://pkgs.k8s.io/core:/stable:/v1.37/deb/

##### [d] Determine which version to upgrade to 

sudo apt-cache madison kubeadm

Output:

	kubeadm | 1.37.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.37/deb  Packages
	
	kubeadm | 1.37.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.37/deb  Packages

##### [e] Upgrade the kubeadm [Like I am doing upgrade to 1.37.0-1.1] 

sudo apt-mark unhold kubeadm && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.37.0-1.1' && \
sudo apt-mark hold kubeadm

##### [f] validate the version:

sudo kubeadm version

##### [g] Execute the upgrade Plan

sudo kubeadm upgrade plan 


##### [h] Performs upgrade (choose similar version as you have done for kubeadm component )

sudo kubeadm upgrade apply v1.37.0

Expected output:

[upgrade/versions] Cluster version: v1.36.0

[upgrade/versions] kubeadm version: v1.37.0

[upgrade] Are you sure you want to proceed? [y/N]: Y


##### [i] Upgrade the kubelet and kubectl 

[Drain the control node]

kubectl drain cp01 --ignore-daemonsets

[Upgrade kubelet and kubectl]

sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && sudo apt-get install -y kubelet='1.37.0-1.1' kubectl='1.37.0-1.1' && \
sudo apt-mark hold kubelet kubectl

[Restart kubelet]

sudo systemctl daemon-reload

sudo systemctl restart kubelet

[Uncordon control node]

kubectl uncordon cp01

### Step-2: Upgrade Additional Control Plane nodes [Optional]

#### Changing the repository on the control Node

##### [a] Print the current repository contents: 

pager /etc/apt/sources.list.d/kubernetes.list

##### [b] Modify the version from "v1.36" to "v1.37"

From - https://pkgs.k8s.io/core:/stable:/v1.36/deb/

To - https://pkgs.k8s.io/core:/stable:/v1.37/deb/

sudo sed -i 's|v1.36|v1.37|g' /etc/apt/sources.list.d/kubernetes.list

##### [c] Check once again it shoud show you 1.37

pager /etc/apt/sources.list.d/kubernetes.list

Expected output: https://pkgs.k8s.io/core:/stable:/v1.37/deb/

##### [d] Determine which version to upgrade to 

sudo apt-cache madison kubeadm

Output:

	kubeadm | 1.37.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.37/deb  Packages
	
	kubeadm | 1.37.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.37/deb  Packages

##### [e] Upgrade the kubeadm [Like I am doing upgrade to 1.37.0-1.1] 

sudo apt-mark unhold kubeadm && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.37.0-1.1' && \
sudo apt-mark hold kubeadm

##### [f] validate the version:

sudo kubeadm version

##### [g] Execute the upgrade Plan

sudo kubeadm upgrade plan 


##### [h] Performs upgrade (choose similar version as you have done for kubeadm component )

sudo kubeadm upgrade node v1.37.0

Expected output:

[upgrade/versions] Cluster version: v1.36.0

[upgrade/versions] kubeadm version: v1.37.0

[upgrade] Are you sure you want to proceed? [y/N]:

##### [i] Upgrade the kubelet and kubectl 

[Drain the control node from the secondary control node ]

kubectl drain <node> --ignore-daemonsets

[Upgrade kubelet and kubectl]
sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && sudo apt-get install -y kubelet='1.37.0-1.1' kubectl='1.37.0-1.1' && \
sudo apt-mark hold kubelet kubectl

[Restart kubelet]

sudo systemctl daemon-reload && sudo systemctl restart kubelet

[Uncordon control node from primary control node ]

kubectl uncordon <node>


### Step-3: Upgrade worker nodes  [Perform the upgrades one by one not both on all nodes ]

#### Changing the repository on the Worker Nodes 

##### [a] Print the current repository contents: 

pager /etc/apt/sources.list.d/kubernetes.list

##### [b] Modify the version from "v1.36" to "v1.37"

From - https://pkgs.k8s.io/core:/stable:/v1.36/deb/

To - https://pkgs.k8s.io/core:/stable:/v1.37/deb/

sudo sed -i 's|v1.36|v1.37|g' /etc/apt/sources.list.d/kubernetes.list

##### [c] Check once again it shoud show you 1.37

pager /etc/apt/sources.list.d/kubernetes.list

Expected output: https://pkgs.k8s.io/core:/stable:/v1.37/deb/


##### [d] Perform the upgrade 

sudo apt-mark unhold kubeadm kubectl && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.37.0-1.1' kubectl='1.37.0-1.1' && \
sudo apt-mark hold kubeadm kubectl

##### [e] Call kubeadm upgrade 

sudo kubeadm upgrade node


##### [f] Draing the node from control plane:

kubectl drain <node-to-drain> --ignore-daemonsets --delete-emptydir-data

##### [g] Upgrade kubelet from the node 

sudo apt-mark unhold kubelet && \
sudo apt-get update && sudo apt-get install -y kubelet='1.37.0-1.1' && \
sudo apt-mark hold kubelet


##### [h] Restart kubelet on nodes 

sudo systemctl daemon-reload && sudo systemctl restart kubelet


##### [i] Uncordon the node [from Control plane]

kubectl uncordon <node-to-uncordon>




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

dhcp_release virbr0 192.168.122.106 52:54:00:3e:70:e5
