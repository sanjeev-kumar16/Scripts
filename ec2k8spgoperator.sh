#!/bin/bash

set -e

echo "Starting setup for Kubernetes and Zalando PostgreSQL Operator on EC2..."

# Variables (customize as needed)
CLUSTER_NAME="zalando-pg-cluster"
STORAGE_CLASS_NAME="ebs-sc"
POSTGRESQL_VERSION="16"
AWS_REGION="us-east-1"
EBS_VOLUME_TYPE="gp3"
EBS_VOLUME_SIZE="10Gi"
NAMESPACE="default"

# Update and Install dependencies
echo "Installing required dependencies..."
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release jq awscli

# Install Docker
echo "Installing Docker..."
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Install kubeadm, kubelet, kubectl
echo "Installing Kubernetes components..."
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Initialize Kubernetes cluster
echo "Initializing Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl for the current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel CNI for networking
echo "Installing Flannel for pod networking..."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Allow scheduling pods on master node (optional for single-node setups)
kubectl taint nodes --all node-role.kubernetes.io/master-

# Install AWS EBS CSI Driver
echo "Installing AWS EBS CSI Driver..."
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/e2e?ref=release-1.14"

# Create StorageClass for AWS EBS
echo "Configuring StorageClass for persistent storage..."
cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: $STORAGE_CLASS_NAME
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: $EBS_VOLUME_TYPE
  encrypted: "true"
EOF

# Install Zalando PostgreSQL Operator
echo "Installing Zalando PostgreSQL Operator..."
kubectl apply -f https://github.com/zalando/postgres-operator/releases/latest/download/postgres-operator.yaml

# Wait for operator to be ready
kubectl rollout status deployment/postgres-operator

# Deploy PostgreSQL cluster
echo "Deploying PostgreSQL cluster with persistent storage and HA..."
cat <<EOF | kubectl apply -f -
apiVersion: "acid.zalan.do/v1"
kind: postgresql
metadata:
  name: $CLUSTER_NAME
  namespace: $NAMESPACE
spec:
  teamId: "acid"
  volume:
    size: $EBS_VOLUME_SIZE
  numberOfInstances: 3
  enableConnectionPooler: true
  postgresql:
    version: "$POSTGRESQL_VERSION"
  resources:
    requests:
      cpu: "500m"
      memory: "500Mi"
  users:
    zalando:
      - superuser
      - createdb
  databases:
    mydatabase: zalando
  allowedSourceRanges:
    - 0.0.0.0/0
EOF

# Install Prometheus and Grafana for Monitoring
echo "Setting up monitoring with Prometheus and Grafana..."
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml
kubectl apply -f https://raw.githubusercontent.com/grafana/helm-charts/main/charts/grafana/templates/deployment.yaml

# Expose Grafana via LoadBalancer
cat <<EOF | kubectl apply -f -
kind: Service
apiVersion: v1
metadata:
  name: grafana
  namespace: $NAMESPACE
spec:
  type: LoadBalancer
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: grafana
EOF

# Install PostgreSQL Exporter for Metrics
echo "Installing PostgreSQL metrics exporter..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-exporter
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-exporter
  template:
    metadata:
      labels:
        app: postgres-exporter
    spec:
      containers:
      - name: postgres-exporter
        image: prometheuscommunity/postgres-exporter
        ports:
        - containerPort: 9187
EOF

# Configure Prometheus to scrape metrics
PROMETHEUS_CONFIG_MAP=$(kubectl get configmap -n monitoring -o name | grep prometheus | head -n 1)
kubectl patch configmap $PROMETHEUS_CONFIG_MAP -n monitoring --type=json -p='[{
  "op": "add",
  "path": "/data/postgres-scrape-config",
  "value": "
    - job_name: postgres
      static_configs:
      - targets: [\"postgres-exporter:9187\"]
  "
}]'

echo "Setup complete!"
echo "PostgreSQL, persistent storage, HA, and monitoring are now configured."
