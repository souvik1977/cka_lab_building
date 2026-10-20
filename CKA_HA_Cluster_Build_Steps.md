## Creating the Nodes [On base machine]

[Rename your main.tf as you will use new-main.tf for building the HA setup]

cd cka-lab && mv main.tf main.tf.disabled   #this main.tf is for one control plane setup

[Release any remitences related to IP Addresses from destroyed cluster]

virsh net-dhcp-leases default

dhcp_release virbr0 <IP_Address> <MAC_Address>  #Replace place holders with correct values


[Updating /etc/hosts ]

sed -i 's|192.168.122.4|192.168.122.179|g' /etc/host

sed -i 's|192.168.122.214|192.168.122.227|g' /etc/hosts

sed -i 's|192.168.122.147|192.168.122.19|g' /etc/hosts

[New entries]

grep -qF '192.168.122.71' /etc/hosts || echo '192.168.122.71 cp02.lab.example.com cp02' >> /etc/hosts

grep -qF '192.168.122.232' /etc/hosts || echo '192.168.122.232 cp03.lab.example.com cp03' >> /etc/hosts

[Modify your '.ssh/config' file to add entries for cp02 and cp03]

Host cp01

        Hostname cp01.lab.example.com
		
        User ubuntu
		
        IdentityFile /home/souvik/.ssh/id_ed25519
		
        StrictHostKeyChecking no
		
        UserKnownHostsFile /dev/null

Host cp02

        Hostname cp02.lab.example.com
		
        User ubuntu
		
        IdentityFile /home/souvik/.ssh/id_ed25519
		
        StrictHostKeyChecking no
		
        UserKnownHostsFile /dev/null

Host cp03

        Hostname cp03.lab.example.com
		
        User ubuntu
		
        IdentityFile /home/souvik/.ssh/id_ed25519
		
        StrictHostKeyChecking no
		
        UserKnownHostsFile /dev/null

Host worker01

        Hostname worker01.lab.example.com
		
        User ubuntu
		
        IdentityFile /home/souvik/.ssh/id_ed25519
		
        StrictHostKeyChecking no
		
        UserKnownHostsFile /dev/null

Host worker02

        Hostname worker02.lab.example.com
		
        User ubuntu
		
        IdentityFile /home/souvik/.ssh/id_ed25519
		
        StrictHostKeyChecking no
		
        UserKnownHostsFile /dev/null

Host usrv01

        Hostname usrv01.lab.example.com
		
        User ubuntu
		
        IdentityFile /home/souvik/.ssh/id_ed25519
		
        StrictHostKeyChecking no
		
        UserKnownHostsFile /dev/null
		


##### Set hostname [All Nodes]

[Control Node 1]

sudo hostnamectl set-hostname cp01.lab.example.com

sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg <<EOF

preserve_hostname: true

fqdn: cp01.lab.example.com

hostname: cp01

create_hostname_file: true

EOF

sudo cloud-init clean

sudo grep -R preserve_hostname /etc/cloud

[Control Node 2]

sudo hostnamectl set-hostname cp02.lab.example.com

sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg <<EOF

preserve_hostname: true

fqdn: cp02.lab.example.com

hostname: cp02

create_hostname_file: true

EOF

sudo cloud-init clean

sudo grep -R preserve_hostname /etc/cloud


[Control Node 3]

sudo hostnamectl set-hostname cp03.lab.example.com

sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg <<EOF

preserve_hostname: true

fqdn: cp03.lab.example.com

hostname: cp03

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




##### Update /etc/hosts [All Nodes]

sudo sed -i '/cp01/d' /etc/hosts

sudo sed -i '/cp02/d' /etc/hosts

sudo sed -i '/cp03/d' /etc/hosts

sudo sed -i '/worker01/d' /etc/hosts

sudo sed -i '/worker02/d' /etc/hosts

sudo sed -i '/k8s-api/d' /etc/hosts

sudo sh -c 'cat >> /etc/hosts <<EOF 
192.168.122.179 cp01.lab.example.com cp01

192.168.122.71 cp02.lab.example.com cp02

192.168.122.232 cp03.lab.example.com cp03

192.168.122.214 worker01.lab.example.com worker01

192.168.122.147 worker02.lab.example.com worker02 

192.168.122.100 k8s-api.lab.example.com k8s-api

EOF'

grep -qF '192.168.122.100' /etc/hosts || echo '192.168.122.100 k8s-api.lab.example.com k8s-api' | sudo tee -a /etc/hosts



##### Checking hosts entries:
getent hosts cp01

getent hosts cp02

getent hosts cp03

getent hosts worker01

getent hosts worker02


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

## Installing Packages [All Nodes]

sudo apt-get update

sudo apt-get install -y curl gpg ca-certificates apt-transport-https

sudo install -m 0755 -d /etc/apt/keyrings


## Setting up Kubernetes Version [All Nodes]

export KUBERNETES_VERSION=v1.36 [ 

[ #later we will upgrade from 1.36 -> 1.37 and from 1.37.x -> 1.37.y]

## Adding Kubernetes Repositories [All Nodes]

curl -fsSL \
"https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key" \
| sudo gpg --dearmor --yes \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list


## Installing kubelet, kubeadm, kubectl, [cri-o] [All Nodes]

sudo apt-get update && \
sudo apt-get install -y kubelet kubeadm kubectl && \
sudo apt-mark hold kubelet kubeadm kubectl


## Install and Configure containerd [All Nodes]

sudo apt install -y containerd && \
sudo mkdir -p /etc/containerd && \
containerd config default | sudo tee /etc/containerd/config.toml

#### Enable cgroup for containerd:

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

#### Starting Containerd [All Nodes]

sudo systemctl restart containerd && \
sudo systemctl enable containerd && \
sudo systemctl status containerd --no-pager

## Configuring HA Proxy [On All Control Nodes]

sudo apt install -y haproxy keepalived

#### Allow non-local IP Bindings on the kernel [Control Nodes]

echo "net.ipv4.ip_nonlocal_bind=1" | sudo tee -a /etc/sysctl.conf

sudo sysctl -p

#### Configure keepalived (VIP) management on CP01 [Master Node]:

sudo tee /etc/keepalived/keepalived.conf << 'EOF'

global_defs {

   router_id LVS_DEVEL
   
   # vrrp_strict can break VIP reachability if not configured with precise firewall rules; it is typically commented out for K8s clusters
   
   # vrrp_strict 
}

# Script used to check if HAProxy is running
vrrp_script check_haproxy {

    script "killall -0 haproxy"
    
    interval 2
    
    weight 2
}

vrrp_instance VI_1 {

    state MASTER          # Set to BACKUP on your secondary load balancer node
    
    interface ens3        # Double-check your network interface name (e.g., eth0, ens3)
    
    virtual_router_id 51  # Must match across all nodes in the cluster
    
    priority 101          # Set to 100 on your secondary load balancer node
    
    advert_int 1
    
    authentication {
    
        auth_type PASS
        
        auth_pass K8sClusterPass
    }
    
    virtual_ipaddress {
    
        192.168.122.100/24
    }
    
    track_script {
    
        check_haproxy
    }
}
EOF

sudo sed -i 's|eth0|ens3|g' /etc/keepalived/keepalived.conf  #Replace ens3 with actual eth card name

sudo cat /etc/keepalived/keepalived.conf


sudo systemctl daemon-reload && \
sudo systemctl restart keepalived && \
sudo systemctl enable keepalived

ip addr show ens3  #this should show that 192.168.122.100 is bind with the eth card on cp01

#### On cp02 [Secondary Control Nodes]

sudo tee /etc/keepalived/keepalived.conf << 'EOF'
global_defs {
   router_id LVS_DEVEL
   # vrrp_strict can break VIP reachability if not configured with precise firewall rules; it is typically commented out for K8s clusters
   # vrrp_strict 
}

# Script used to check if HAProxy is running
vrrp_script check_haproxy {

    script "killall -0 haproxy"
    
    interval 2
    
    weight 2
}

vrrp_instance VI_1 {

    state BACKUP          # Set to BACKUP on your secondary load balancer node
    
    interface ens3        # Double-check your network interface name (e.g., eth0, ens3)
    
    virtual_router_id 51  # Must match across all nodes in the cluster
    
    priority 100          # Set to 100 on your secondary load balancer node
    
    advert_int 1
    
    authentication {
    
        auth_type PASS
        
        auth_pass K8sClusterPass
    }
    
    virtual_ipaddress {
    
        192.168.122.100/24
    }
    
    track_script {
    
        check_haproxy
    }
}
EOF

sudo sed -i 's|eth0|ens3|g' /etc/keepalived/keepalived.conf  #Replace ens3 with actual eth card name

sudo cat /etc/keepalived/keepalived.conf

sudo systemctl daemon-reload && \
sudo systemctl restart keepalived && \
sudo systemctl enable keepalived



#### On cp03 [Secondary Control Nodes]

sudo tee /etc/keepalived/keepalived.conf << 'EOF'
global_defs {
   router_id LVS_DEVEL
   # vrrp_strict can break VIP reachability if not configured with precise firewall rules; it is typically commented out for K8s clusters
   # vrrp_strict 
}

# Script used to check if HAProxy is running
vrrp_script check_haproxy {
    script "killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state BACKUP          # Set to BACKUP on your secondary load balancer node
    interface ens3        # Double-check your network interface name (e.g., eth0, ens3)
    virtual_router_id 51  # Must match across all nodes in the cluster
    priority 99           # Set to 100 on your secondary load balancer node
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass K8sClusterPass
    }
    
    virtual_ipaddress {
        192.168.122.100/24
    }
    
    track_script {
        check_haproxy
    }
}
EOF

sudo sed -i 's|eth0|ens3|g' /etc/keepalived/keepalived.conf  #Replace ens3 with actual eth card name

sudo cat /etc/keepalived/keepalived.conf

sudo systemctl daemon-reload && \
sudo systemctl restart keepalived && \
sudo systemctl enable keepalived

#### Configure HAProxy [all control nodes]

sudo mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak


sudo tee /etc/haproxy/haproxy.cfg << 'EOF'

global
    log /dev/log local0
    
    log /dev/log local1 notice
    
    chroot /var/lib/haproxy
    
    user haproxy
    
    group haproxy
    
    daemon
    

defaults
    log     global
    
    mode    tcp
    
    option  tcplog
    
    option  dontlognull
    
    # Essential timeouts for Kubernetes API stability
    
    timeout connect 10s
    
    timeout client  1m
    
    timeout server  1m

#---------------------------------------------------------------------
# Kubernetes Control Plane Frontend
#---------------------------------------------------------------------
frontend k8s_apiserver_frontend

	# Replace the ip address as per your setup 
  
    bind 192.168.122.100:6443      
    
    mode tcp
    
    option tcplog
    
    default_backend k8s_apiserver_backend

#---------------------------------------------------------------------
# Kubernetes Control Plane Backends
#---------------------------------------------------------------------

backend k8s_apiserver_backend

    mode tcp
    
    option tcp-check
    
    balance roundrobin
    
    # Replace the placeholder IPs (192.168.122.X) below with your actual Control Plane node IPs
    
    server cp01 192.168.122.179:6443 check fall 3 rise 2
    
    server cp02 192.168.122.71:6443 check fall 3 rise 2
    
    server cp03 192.168.122.232:6443 check fall 3 rise 2

EOF

sudo haproxy -c -f /etc/haproxy/haproxy.cfg


sudo systemctl restart haproxy

## Installing crictl on the control-planes

export CRICTL_VERSION="v1.36.0"

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


## Autocomplete the profile

cp ~/.bashrc ~/.bashrc.bkp

source <(kubectl completion bash)

echo "source <(kubectl completion bash)" >> ~/.bashrc

echo "complete -o default -F __start_kubectl k" >> ~/.bashrc

source ~/.bashrc



## Configure kubeadm-config.yaml [On CP01]:

sudo tee kubeadm-config.yaml << 'EOF'
---
apiVersion: kubeadm.k8s.io/v1beta4

kind: InitConfiguration

localAPIEndpoint:

  advertiseAddress: 192.168.122.179
  
  bindPort: 6443

nodeRegistration:

  name: cp01.lab.example.com
  
  criSocket: unix:///run/containerd/containerd.sock

---
apiVersion: kubeadm.k8s.io/v1beta4

kind: ClusterConfiguration

clusterName: dev.k8s.cluster

kubernetesVersion: v1.36.5

controlPlaneEndpoint: "k8s-api.lab.example.com:6443"

networking:

  serviceSubnet: 10.96.0.0/12
  
  podSubnet: 10.240.0.0/16
  
  dnsDomain: lab.example.com

apiServer:

  certSANs:
  
    - k8s-api.lab.example.com
    
    - 192.168.122.100
    
    - cp01.lab.example.com
    
    - cp02.lab.example.com
    
    - cp03.lab.example.com
    
    - 192.168.122.179
    
    - 192.168.122.71
    
    - 192.168.122.232

etcd:

  local:
  
    dataDir: /var/lib/etcd
EOF

###### Check preflight 

sudo systemctl stop haproxy
 
sudo kubeadm init phase preflight \
  --config kubeadm-config.yaml

###### Dry-run 
sudo kubeadm init \
  --config kubeadm-config.yaml \
  --upload-certs \
  --dry-run
  

sudo kubeadm init \
  --config=kubeadm-config.yaml \
  --upload-certs
  

#### Modify kube-apiserver.yaml to use local IP address

IP=$(hostname -I | awk '{print $1}') && \
sudo sed -i "/--advertise-address=/a\    - --bind-address=${IP}" \
/etc/kubernetes/manifests/kube-apiserver.yaml


###### Verify:

sudo grep -A2 advertise-address /etc/kubernetes/manifests/kube-apiserver.yaml

sudo crictl ps | grep kube-apiserver

sudo systemctl start haproxy

sudo systemctl enable haproxy

sudo systemctl status haproxy

## Configure other control nodes :

sudo systemctl stop haproxy

sudo kubeadm join k8s-api.lab.example.com:6443 --token <token> \
        --discovery-token-ca-cert-hash sha256:<hash> \
        --control-plane --certificate-key <certificate>

#### Modify kube-apiserver.yaml to use local IP address

IP=$(hostname -I | awk '{print $1}') && \
sudo sed -i "/--advertise-address=/a\    - --bind-address=${IP}" \
/etc/kubernetes/manifests/kube-apiserver.yaml


###### Verify:

sudo grep -A2 advertise-address /etc/kubernetes/manifests/kube-apiserver.yaml

sudo systemctl start haproxy

sudo systemctl enable haproxy

## Configure profile for kubectl on all control nodes:

mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config


## Checking

sudo ss -tnlp | grep kube-apiserver

sudo ss -tnlp | grep 6443

nc -zv k8s-api.lab.example.com 6443


## Installing Calico manifests files [Control Planes]:

wget -4 -O calico.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml

wget -4 -O custom-resources.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml

sed -i 's|cidr: 192.168.0.0/16|cidr: 10.240.0.0/16|g' custom-resources.yaml


kubectl apply -f calico.yaml

kubectl apply -f custom-resources.yaml

kubectl get pods -n calico-system


## Configuring Worker Nodes:

JOIN_CMD=$(sudo kubeadm token create --print-join-command)

echo "$JOIN_CMD"

nc -zv k8s-api.lab.example.com 6443

sudo kubeadm join k8s-api.lab.example.com:6443 --token <token> \
        --discovery-token-ca-cert-hash sha256:<hash>
		

#### Fix labels

kubectl label node cp01 \
  node-role.kubernetes.io/control-plane="" --overwrite
  
kubectl label node worker01.lab.example.com \
  node-role.kubernetes.io/worker-node=worker --overwrite

kubectl label node worker02.lab.example.com \
  node-role.kubernetes.io/worker-node=worker --overwrite


## Troubleshooting

#### Resetting cluster Node:

sudo kubeadm reset -f

sudo systemctl stop kubelet

sudo rm -rf /etc/cni/net.d $HOME/.kube/config

#### HAProxy failure

sudo journalctl -u haproxy -n 50 --no-pager

#### etcd not starting on secondary control planes:

sudo apt install etcd-client

###### Checking on CP01 health 

sudo etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

###### Checking membership on CP01 

sudo etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list --write-out=table
  
##### Remove etcd membership [On CP02]

sudo kubeadm reset -f \
  --cri-socket=unix:///run/containerd/containerd.sock \
  --skip-phases=remove-etcd-member

sudo systemctl stop kubelet

sudo mv /var/lib/etcd \
  /var/lib/etcd-removed-member-$(date +%Y%m%d-%H%M%S)
  
[clean everything]

sudo rm -rf /etc/kubernetes/manifests/*

sudo rm -rf /var/lib/kubelet/*

sudo rm -rf /etc/cni/net.d/*


sudo systemctl restart containerd


###### On CP01 - remove the CP02 or other steal Nodes

kubectl delete node cp02.lab.example.com --ignore-not-found


###### On CP01 - Generate fresh join command for CP02 and CP03 

JOIN_CMD=$(sudo kubeadm token create --print-join-command)

echo "$JOIN_CMD"

[upload certificate]

CERT_KEY=$(sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1)

echo "$CERT_KEY"


echo "sudo ${JOIN_CMD} --control-plane --certificate-key ${CERT_KEY} --cri-socket unix:///run/containerd/containerd.sock"

##### On CP02 and CP03 execute the command you will get from above command 

sudo kubeadm join k8s-api.lab.example.com:6443 \
--token t6uynl.vxf375q9fks6tvqt \
--discovery-token-ca-cert-hash sha256:1922c961b86178c662d7f96b1ccebfdb3df03f809713e5ae387ce8e8b44f55fe  \
--control-plane \
--certificate-key d1baa2008465588305324ce6f4cfe7abf663d1726761332705f08f3dc630d5d2 \
--cri-socket unix:///run/containerd/containerd.sock


####### Verify 

sudo crictl ps -a | egrep 'etcd|kube-apiserver'


###### Checking membership on CP01 
sudo etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list --write-out=table



## Testings:

##### Testing HA

[On CP01]

ip addr | grep 192.168.122.100

sudo systemctl stop keepalived

[On CP02]

ip addr | grep 192.168.122.100

kubectl get nodes


##### Testing Node Failure

[On CP01]

sudo shutdown now

[On CP02]

kubectl get nodes

##### Testing etcd membership

sudo ETCDCTL_API=3 etcdctl \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
member list --write-out=table


###### Testing cluster endpoint 

kubectl cluster-info
