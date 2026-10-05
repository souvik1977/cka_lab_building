# Configuring Zonal 3 node GKE cluster

## In this lab we will perform

### 1. Network: Creating VPC, Subnets, Pod IP Range, Service IP Range 
### 2. Service Accounts: Creating Roles, Service Accounts, adding roles to service accounts 
### 3. GKE: Creating a GKE Control plane with default node-pool 
### 4. Node-Pool: Delete default node pool, create a new node-pool and attach to cluster
### 5. Cluster connect: Installing required packages, connect to cluster 

## Pre-requisite: If you want to use local machine instead of cloud-shell, install gcloud:

### RedHat/Ubuntu:
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz

tar -xf google-cloud-cli-linux-x86_64.tar.gz

./google-cloud-sdk/install.sh

source .bashrc

gcloud init 

## [1] - Exporting required variables (this step might need to execute everytime you are reconnecting to cloudshell or your local machine):
export PROJECT_ID="project-xxxx-yyyy-zzzz-aaaa"

export BILLING_ACCOUNT_ID="XXXXX-XXXXX-XXXXX"

export ADMIN_EMAIL="YOUR_EMAIL@gmail.com"

export OPERATOR_EMAIL="USER_EMAIL@gmail.com"

export REGION="asia-south1"

export ZONE="asia-south1-a"

export NETWORK_NAME="gke-lab-vpc"

export SUBNET_NAME="gke-zonal-subnet"

export SUBNET_PRIMARY_CIDR="10.10.0.0/24"

export POD_RANGE_NAME="gke-zonal-pods"

export POD_RANGE_CIDR="10.20.0.0/16"

export SERVICE_RANGE_NAME="gke-zonal-services"

export SERVICE_RANGE_CIDR="10.30.0.0/20"

export CLUSTER_NAME="gke-standard-zonal-01"

export NODE_POOL_NAME="app-pool"

export NODE_SA_NAME="gke-zonal-node-sa"

export AR_REPOSITORY="gke-app-repo"

export IMAGE_NAME="custom-nginx"

export IMAGE_TAG="v1"

export NAMESPACE="production"

export NODE_SA_EMAIL="${NODE_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

export IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"


### Creating a script named .env_vars.sh under the shell and put all the above environment variables there

chmod +x .env_vars.sh

source ./.env_vars.sh

## [2] - Check variables:

printf '%-25s %s\n' \
"PROJECT_ID" "$PROJECT_ID" \
"ADMIN_EMAIL" "$ADMIN_EMAIL" \
"OPERATOR_EMAIL" "$OPERATOR_EMAIL" \
"REGION" "$REGION" \
"ZONE" "$ZONE" \
"CLUSTER_NAME" "$CLUSTER_NAME" \
"NODE_POOL_NAME" "$NODE_POOL_NAME" \
"NODE_SA_EMAIL" "$NODE_SA_EMAIL" \
"IMAGE_URI" "$IMAGE_URI"

## [3] - Enabling APIs:

gcloud services enable   container.googleapis.com   compute.googleapis.com   iam.googleapis.com   iamcredentials.googleapis.com   cloudresourcemanager.googleapis.com   serviceusage.googleapis.com   artifactregistry.googleapis.com   cloudbuild.googleapis.com   logging.googleapis.com   monitoring.googleapis.com   containeranalysis.googleapis.com

## [4] - Listing enabled APIs:

gcloud services list --enabled --filter="config.name:(container.googleapis.com OR compute.googleapis.com OR artifactregistry.googleapis.com OR cloudbuild.googleapis.com OR logging.googleapis.com OR monitoring.googleapis.com)" --format="table(config.name)"

## [5] - Configuring a new profile: 

gcloud config configurations create gke-admin

gcloud auth login "$ADMIN_EMAIL"

gcloud config configurations list

## [6] - Updating the new-profile with default values:

gcloud config set account "$ADMIN_EMAIL"

gcloud config set project "$PROJECT_ID"

gcloud config set compute/region "$REGION"

gcloud config set compute/zone "$ZONE"

## [7] - Creating a Project 
gcloud projects create "$PROJECT_ID" --name="GKE Hands-on Lab"

gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT_ID"

gcloud billing projects describe "$PROJECT_ID"

gcloud config set project "$PROJECT_ID"

## [8] - Get IAM policy:
  
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:${ADMIN_EMAIL}" \
  --format="table(bindings.role)"

## [9] - Perform below steps if your permission is not 'owner' and you are a delegated admin (Super admins need to perform below steps)

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${ADMIN_EMAIL}" \
  --role="roles/serviceusage.serviceUsageAdmin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${ADMIN_EMAIL}" \
  --role="roles/compute.networkAdmin"
  
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${ADMIN_EMAIL}" \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${ADMIN_EMAIL}" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${ADMIN_EMAIL}" \
  --role="roles/resourcemanager.projectIamAdmin"
  
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${ADMIN_EMAIL}" \
  --role="roles/artifactregistry.admin"


gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${ADMIN_EMAIL}" \
  --role="roles/cloudbuild.builds.editor"
  
gcloud compute networks create "$NETWORK_NAME" \
  --subnet-mode=custom \
  --bgp-routing-mode=regional


## [10] - [Network] - Creation

gcloud compute networks describe "$NETWORK_NAME"

gcloud compute networks subnets create "$SUBNET_NAME" \
  --network="$NETWORK_NAME" \
  --region="$REGION" \
  --range="$SUBNET_PRIMARY_CIDR" \
  --secondary-range="${POD_RANGE_NAME}=${POD_RANGE_CIDR},${SERVICE_RANGE_NAME}=${SERVICE_RANGE_CIDR}" \
  --enable-private-ip-google-access


## [11] - Verify Network:

gcloud compute networks subnets describe "$SUBNET_NAME" \
  --region="$REGION" \
  --format="yaml(name,network,ipCidrRange,privateIpGoogleAccess,secondaryIpRanges)"

## [12] - Create a dedicated GKE node service account:

gcloud iam service-accounts create "$NODE_SA_NAME" \
  --display-name="GKE zonal cluster node service account" \
  --description="Least-privileged identity for GKE worker nodes"

gcloud iam service-accounts describe "$NODE_SA_EMAIL"

## [13] - Granting permission to service account:

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${NODE_SA_EMAIL}" \
  --role="roles/container.defaultNodeServiceAccount"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${NODE_SA_EMAIL}" \
  --role="roles/artifactregistry.reader"

## [14] - Allow admin to attach this role to nodes:

gcloud iam service-accounts add-iam-policy-binding "$NODE_SA_EMAIL" \
  --member="user:${ADMIN_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

## [15] Verify Service Account Permission:

gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${NODE_SA_EMAIL}" \
  --format="table(bindings.role)"

## [16] Create Artifact Registry:

gcloud artifacts repositories create "$AR_REPOSITORY" \
  --repository-format=docker \
  --location="$REGION" \
  --description="Container images for the GKE hands-on lab"
  
## [17] Verify Artifact Registry:

gcloud artifacts repositories describe "$AR_REPOSITORY" \
  --location="$REGION"
  
## [18] - Configure Cloud Build permissions:

export CLOUD_BUILD_SA="$(gcloud builds get-default-service-account)"

echo "$CLOUD_BUILD_SA"

## [19] - Grant writer permission to this service account on Repository:

gcloud artifacts repositories add-iam-policy-binding "$AR_REPOSITORY" \
  --location="$REGION" \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role="roles/artifactregistry.writer"

## [20] - Verify Artifact Registry:

gcloud artifacts repositories get-iam-policy "$AR_REPOSITORY" \
  --location="$REGION"

## [21] - Creating a cluster:

###[a] Creating zonal cluster:

gcloud container clusters create "$CLUSTER_NAME" \
  --zone="$ZONE" \
  --network="$NETWORK_NAME" \
  --subnetwork="$SUBNET_NAME" \
  --enable-ip-alias \
  --cluster-secondary-range-name="$POD_RANGE_NAME" \
  --services-secondary-range-name="$SERVICE_RANGE_NAME" \
  --release-channel="regular" \
  --workload-pool="${PROJECT_ID}.svc.id.goog" \
  --enable-shielded-nodes \
  --enable-dataplane-v2 \
  --enable-managed-prometheus \
  --logging="SYSTEM,WORKLOAD" \
  --monitoring="SYSTEM,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA,CADVISOR,KUBELET" \
  --num-nodes=1 \
  --machine-type="e2-medium" \
  --disk-type="pd-balanced" \
  --disk-size="50GB" \
  --service-account="$NODE_SA_EMAIL" \
  --scopes="cloud-platform" \
  --enable-autorepair \
  --enable-autoupgrade

[b] List existing node-pools:

gcloud container node-pools list \
  --cluster="$CLUSTER_NAME" \
  --zone="$ZONE"

[c] Delete default-pool:

gcloud container node-pools delete "default-pool" \
  --cluster="$CLUSTER_NAME" \
  --zone="$ZONE" \
  --quiet
  
[d] Check if node-pools exists or not :

gcloud container node-pools list \
  --cluster="$CLUSTER_NAME" \
  --zone="$ZONE"

## [22] - Creating node-pool:

gcloud container node-pools create "$NODE_POOL_NAME" \
  --cluster="$CLUSTER_NAME" \
  --zone="$ZONE" \
  --num-nodes=3 \
  --machine-type="e2-medium" \
  --disk-type="pd-balanced" \
  --disk-size="50GB" \
  --image-type="COS_CONTAINERD" \
  --service-account="$NODE_SA_EMAIL" \
  --scopes="cloud-platform" \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-autoscaling \
  --min-nodes=3 \
  --max-nodes=5 \
  --max-surge-upgrade=1 \
  --max-unavailable-upgrade=0 \
  --node-labels="environment=lab,workload=application,nodepool=${NODE_POOL_NAME}"

## [23] - Verify node-pool:

gcloud container node-pools describe "$NODE_POOL_NAME" \
  --cluster="$CLUSTER_NAME" \
  --zone="$ZONE" \
  --format="yaml(name,config.machineType,config.serviceAccount,initialNodeCount,autoscaling,management,upgradeSettings)"

## [24] - Connect to Cluster:

gcloud components install kubectl gke-gcloud-auth-plugin

if above command failed then run:

sudo apt-get install kubectl google-cloud-cli-gke-gcloud-auth-plugin

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone="$ZONE" \
  --project="$PROJECT_ID"

kubectl cluster-info

kubectl get nodes -o wide

### Validate Lables:

kubectl get nodes \
  -L cloud.google.com/gke-nodepool,topology.kubernetes.io/zone,environment,workload
  
##################### Optional ################################################

## [25] - Creating Delegated account for cluster management:

### This preserves the separation between Google Cloud infrastructure administration and Kubernetes platform operations.

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${OPERATOR_EMAIL}" \
  --role="roles/container.clusterViewer"

### Granting basic project visibility:

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${OPERATOR_EMAIL}" \
  --role="roles/viewer"
  

kubectl create clusterrolebinding delegated-gke-operator \
  --clusterrole=cluster-admin \
  --user="$OPERATOR_EMAIL"

### Verify:

kubectl get clusterrolebinding delegated-gke-operator -o yaml



## [26] - Switch to delegated user:

gcloud config configurations create gke-operator

gcloud auth login "$OPERATOR_EMAIL"

gcloud auth login --no-launch-browser



gcloud config set account "$OPERATOR_EMAIL"

gcloud config set project "$PROJECT_ID"

gcloud config set compute/region "$REGION"

gcloud config set compute/zone "$ZONE"


## [27] - Retrieve Credentials as the operator:

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone="$ZONE" \
  --project="$PROJECT_ID"

### Verify auth:

gcloud auth list

## [28] - Test kubernetes access:

kubectl auth can-i get nodes

kubectl auth can-i create namespaces

kubectl auth can-i create deployments --all-namespaces

kubectl auth can-i delete nodes


## [29] - Build Steps:

### [a] - Switch back to administrator from operator:

gcloud config configurations activate gke-admin

### [b] - Verify:

gcloud config get-value account


## [30] - Create custom nginx-application:

mkdir -p ~/gke-day1/custom-nginx

cd ~/gke-day1/custom-nginx

### Create the html page:

cat > index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Souvik's GKE Lab</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background: #0f172a;
      color: #e2e8f0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
    }
    .card {
      background: #1e293b;
      border-radius: 16px;
      padding: 40px;
      max-width: 700px;
      box-shadow: 0 12px 30px rgba(0,0,0,0.35);
    }
    h1 { color: #38bdf8; }
    .success { color: #4ade80; font-weight: bold; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Custom NGINX on GKE</h1>
    <p class="success">Deployment successful</p>
    <p>Cluster: gke-standard-zonal-01</p>
    <p>Node pool: app-pool</p>
    <p>Build source: Google Cloud Build</p>
    <p>Image registry: Google Artifact Registry</p>
  </div>
</body>
</html>
EOF


## [31] - Create the Dockerfile:

cat > Dockerfile <<'EOF'
FROM nginx:1.27-alpine

COPY index.html /usr/share/nginx/html/index.html

RUN printf '%s\n' \
    'server {' \
    '    listen 8080;' \
    '    server_name _;' \
    '    root /usr/share/nginx/html;' \
    '    index index.html;' \
    '    location /healthz {' \
    '        access_log off;' \
    '        return 200 "healthy\n";' \
    '        add_header Content-Type text/plain;' \
    '    }' \
    '}' \
    > /etc/nginx/conf.d/default.conf

EXPOSE 8080
EOF

## [32] - Create the Cloud-Build configuration file:

cat > cloudbuild.yaml <<'EOF'
steps:
  - name: "gcr.io/cloud-builders/docker"
    args:
      - "build"
      - "-t"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPOSITORY}/${_IMAGE}:${_TAG}"
      - "."

images:
  - "${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPOSITORY}/${_IMAGE}:${_TAG}"

options:
  logging: CLOUD_LOGGING_ONLY
EOF


## [33] - Build and publish the image:

gcloud builds submit \
  --config="cloudbuild.yaml" \
  --substitutions="_REGION=${REGION},_REPOSITORY=${AR_REPOSITORY},_IMAGE=${IMAGE_NAME},_TAG=${IMAGE_TAG}" \
  .

### Verify:

gcloud builds list \
  --limit=5 \
  --format="table(id,status,createTime,finishTime)"
  

### Verify image:

gcloud artifacts docker images list \
  "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPOSITORY}" \
  --include-tags
  

## [34] - Creating Deployment Manifests:

gcloud config configurations activate gke-operator

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone="$ZONE" \
  --project="$PROJECT_ID"
  
kubectl create namespace "$NAMESPACE"

### Creating the deployment manifests:

cat > nginx-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-nginx
  namespace: ${NAMESPACE}
  labels:
    app: custom-nginx
spec:
  replicas: 3
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: custom-nginx
  template:
    metadata:
      labels:
        app: custom-nginx
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: nginx
          image: ${IMAGE_URI}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 300m
              memory: 128Mi
          startupProbe:
            httpGet:
              path: /healthz
              port: http
            failureThreshold: 30
            periodSeconds: 2
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 2
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: custom-nginx
  namespace: ${NAMESPACE}
spec:
  selector:
    app: custom-nginx
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: http
  type: LoadBalancer
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: custom-nginx-pdb
  namespace: ${NAMESPACE}
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: custom-nginx
EOF


### Deploy:

kubectl apply -f nginx-deployment.yaml

kubectl rollout status deployment/custom-nginx \
  --namespace="$NAMESPACE"

### Verify pod distributions:

kubectl get pods \
  --namespace="$NAMESPACE" \
  -o wide

kubectl get deployment custom-nginx \
  --namespace="$NAMESPACE"

### Check the service:

kubectl get service custom-nginx \
  --namespace="$NAMESPACE"
  

### Store the service address:

export SERVICE_IP="$(kubectl get service custom-nginx \
  --namespace="$NAMESPACE" \
  --output=jsonpath='{.status.loadBalancer.ingress[0].ip}')"
  
### Check the service:

curl "http://${SERVICE_IP}"

### Test the health point:

curl "http://${SERVICE_IP}/healthz"


## [35] - Validate logging:

for i in $(seq 1 20); do
  curl -s "http://${SERVICE_IP}" >/dev/null
done

### Read logs:

kubectl logs \
  --namespace="$NAMESPACE" \
  --selector=app=custom-nginx \
  --tail=20
