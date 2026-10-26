### [Pre-setup] - Declaring user, ns,

export userName="neha"

export ns="sandbox-namespace"

export userConfig="${userName}-kubeconfig"

### [Step-1] - Create the user

sudo useradd -m -s /bin/bash $userName

sudo passwd $userName

### [Step-2] - Create the private-key, csr 

[key] - openssl genrsa -out "${userName}.key" 2048

[csr] - openssl req -new -key "${userName}.key" -out "${userName}.csr" -subj "/CN=${userName}"

### [Step-3] - Create Manifests for user CSR 

[Manifests Creation] -

cat > ${userName}-csr.yaml <<EOF

apiVersion: certificates.k8s.io/v1

kind: CertificateSigningRequest

metadata:
  name: ${userName}-csr

spec:
  
  request: $(cat ${userName}.csr | base64 | tr -d '\n' )
  
  signerName: kubernetes.io/kube-apiserver-client
  
  expirationSeconds: 43200
  
  usages:
  - client auth
  
EOF

[Creating CSR object] - kubectl apply -f ${userName}-csr.yaml

[Extracting the pending CSR] - kubectl get certificatesigningrequests.certificates.k8s.io

[Signing the request ] - kubectl certificate approve ${userName}-csr


### [Step-4] - Creating namespace 

[Creating Manifests file ]

cat << EOF > "NS/${ns}.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: ${ns}
EOF

[Applying the Manifests] - kubectl apply -f NS/${ns}.yaml


### [Step-5] - Creating Role 

[Creating the role Manifests file] -

cat << EOF > "RBAC/${userName}-role.yaml"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${userName}-role
  namespace: ${ns}
rules:
- apiGroups: ["*"]
  verbs: ["*"]
  resources: ["*"]
EOF

[Creating the role] - kubectl apply -f RBAC/${userName}-role.yaml


### [Step-6] - Creating RoleBinding

[Creating the role-Binding-manifests] 

cat << EOF > "RBAC/${userName}-rolebinding.yaml"
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
 name: ${userName}-rolebindig
 namespace: ${ns}
subjects:
- kind: User
  name: ${userName} # "name" is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  # "roleRef" specifies the binding to a Role / ClusterRole
  kind: Role  #this must be Role or ClusterRole
  name: ${userName}-role # this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io
EOF 

[Creating the role binding] - kubectl apply -f RBAC/${userName}-rolebinding.yaml

### [Step-7] - Extracting User Certificate 

kubectl get csr ${userName}-csr -o jsonpath='{.status.certificate}' | base64 --decode > local-pki/${userName}.crt

### [Step-8] - Creating user Profile

current_cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')

SERVER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

CA_CERT=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | tr -d '\n')

kubectl config set-cluster ${current_cluster} --server=${SERVER_URL} --kubeconfig=${userConfig}

kubectl config set "clusters.${current_cluster}.certificate-authority-data" "$CA_DATA" --kubeconfig=${userConfig}


### [Step-9] - Creating User Credential

kubectl config set-credentials ${userName} --kubeconfig=${userConfig} \
--client-certificate="local-pki/${userName}.crt" \
--client-key="local-pki/${userName}.key" \
--embed-certs=true

### [Step-10] - Creating User context

kubectl config set-context ${userName}-context \
--namespace=${ns} \
--user=${userName} \
--cluster=${current_cluster} \
--kubeconfig=${userConfig}

### [Step-11] - Creating config file under user homedirectory

sudo mkdir -p /home/$userName/.kube && \
sudo chown -R $(id -u $userName):$(id -g $userName) /home/$userName
sudo cp ${userConfig} /home/$userName/.kube/config && \
sudo chown $(id -u $userName):$(id -g $userName) /home/$userName/.kube/config


### [Step-12] - Validating certificate 

#### Test the Client Certificate String

sudo kubectl config view --raw --kubeconfig=/home/$userName/.kube/config -o jsonpath='{.users[0].user.client-certificate-data}' | base64 --decode | openssl x509 -text -noout

#### Test the Client Private Key String

sudo kubectl config view --raw --kubeconfig=/home/$userName/.kube/config -o jsonpath='{.users[0].user.client-key-data}' | base64 --decode | openssl rsa -check -noout

su - ${userName}


### [Step-13] - Granting user 'neha' minimal cluster role 

[Creating the role Manifests file] -

cat << EOF > "RBAC/${userName}-clusterrole.yaml"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${userName}-clusterrole
rules:
- apiGroups: [""]
  verbs: ["get", "list", "watch"]
  resources: ["nodes", "componentstatuses"]
EOF

[Creating the role] - kubectl apply -f RBAC/${userName}-clusterrole.yaml

### [Step-14] - Creating RoleBinding

[Creating the role-Binding-manifests] 

cat << EOF > "RBAC/${userName}-clusterrolebinding.yaml"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
 name: ${userName}-clusterrolebinding
subjects:
- kind: User
  name: ${userName} #"name" is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  # "roleRef" specifies the binding to a Role / ClusterRole
  kind: ClusterRole #this must be Role or ClusterRole
  name: ${userName}-clusterrole #this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io
EOF 

[Creating the role binding] - kubectl apply -f RBAC/${userName}-clusterrolebinding.yaml
