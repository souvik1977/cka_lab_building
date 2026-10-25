### Learning Objective - 1
I want to learn Kubernetes RBAC while doing
a. Creating an admin role and bind that an user

	- Creating an user and creating required Certificates for Kubernetes authentication
  
	- Creating a namespace
  
	- Creating a role granting permissions on that namespace 
  
	- Creating a rolebinding to bind the role and the user
  
	- Grant list, get, patch, create, delete permissions for Pod, Services, Deployment for that user on 'default' namespace

Let's perform these actions using imparetive way first and then I want to learn same in declarative way.

While learining, you will give easy understanding on how role, namespace, rolebinding and users are connecting each other

### [Step-1] - User Creation and Certificates Generation:

#### Creating user -

export userName="rajat"

sudo useradd -m -s /bin/bash $userName

sudo passwd $userName

#### Creating a local directory to save keys and certs:

mkdir local-pki && cd local-pki

#### Generating Certificates

##### Private key for user 

openssl genrsa -out $userName.key 2048

#### Create a certificate signing request for the user 

openssl req -new -key $userName.key -out $userName.csr -subj "/CN=$userName"

#### Create Certificate Signing Request YAML Manifests

cat > $userName-csr-req.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $userName-csr
spec:
  request: $(cat $userName.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # 24 hours
  usages:
  - client auth
EOF

kubectl apply -f $userName-csr-req.yaml

#### Get the CSR details:

kubectl get certificatesigningrequests.certificates.k8s.io/harsh-csr -o wide

#### Signing the pending CSR as admin:

kubectl certificate approve $userName-csr

#### Extracting user certificate from signed CSR:

kubectl get csr $userName-csr -o jsonpath='{.status.certificate}' | base64 --decode > $userName.crt

### [Step-2] - Create the namespace 

export new_ns_name="dev-space"

kubectl create namespace $new_ns_name

### [Step-3] - Setting up user credential and creating user context
 
#### Extract the cluster name:

current_cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')

echo $current_cluster

#### Setup-Cluster Connection Details 

SERVER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | tr -d '\n')

kubectl config set-cluster $current_cluster \
  --kubeconfig=$userName-kubeconfig \
  --server=$SERVER_URL

[Inject the raw CA data into the config file]

kubectl config set "clusters.${current_cluster}.certificate-authority-data" "$CA_DATA" --kubeconfig=$userName-kubeconfig


#### Set the credential for the user:

kubectl config set-credentials $userName \
--kubeconfig=$userName-kubeconfig \
--client-certificate=$userName.crt \
--client-key=$userName.key \
--embed-certs=true

#### Get user lists 

[a] Human users exists on the cluster -

kubectl config get-users

[b] Get service accounts

kubectl get serviceaccounts --all-namespaces

[c] Get human users from rolebindings:

kubectl get rolebindings,clusterrolebindings -o json | jq -r '.items[].subjects[]? | select(.kind=="User") | .name'| sort -u

#### Setting the user context:

kubectl config set-context $userName-context \
--kubeconfig=$userName-kubeconfig \
--cluster=$current_cluster \
--user=$userName \
--namespace=$new_ns_name


#### List down all contexts:

kubectl config get-contexts


### [Step-4] - Create a role with full permission on all resources

export new_role_name="dev-admin-role"

kubectl create role $new_role_name --namespace=$new_ns_name --verb="*" --resource="*"


### [Step-5] - Creating role binding

export new_rb_name="${new_role_name}-rolebinding"

kubectl create rolebinding $new_rb_name --namespace=$new_ns_name --role=$new_role_name --user=$userName

### [Step-6] - Creating .kube directory and copy kubernetes config 

sudo mkdir -p /home/$userName/.kube && \
sudo chown -R $(id -u $userName):$(id -g $userName) /home/$userName
sudo mv $userName-kubeconfig /home/$userName/.kube/config && \
sudo chown $(id -u $userName):$(id -g $userName) /home/$userName/.kube/config


### [Step-7] - Validate Certificates

#### Test the Client Certificate String

sudo kubectl config view --raw --kubeconfig=/home/$userName/.kube/config -o jsonpath='{.users[0].user.client-certificate-data}' | base64 --decode | openssl x509 -text -noout

#### Test the Client Private Key String

sudo kubectl config view --raw --kubeconfig=/home/$userName/.kube/config -o jsonpath='{.users[0].user.client-key-data}' | base64 --decode | openssl rsa -check -noout


su - rajat 

kubectl config get-contexts

kubectl config use-context rajat-context



### [Step-8] - Allowing rajat limited permissions on cluster to get, list, watch 


#### Creating the clusterrole -
export clusterRole="prod-cluster-viewer-role"

kubectl create clusterrole $clusterRole --verb=get,list,watch --resource=nodes,componentstatuses

#### Binding the clusterrole with user -

export clusterRoleBinding=${clusterRole}-role-binding 

kubectl create clusterrolebinding $clusterRoleBinding --clusterrole=$clusterRole --user=$userName

#### Describing the custom role and role binding -

kubectl describe clusterrole $clusterRole

kubectl describe clusterrolebinding $clusterRoleBinding


#### Testing as user:

kubectl get nodes 

kubectl get componentstatuses

kubectl cordon worker02.lab.example.com  ## This will fail






