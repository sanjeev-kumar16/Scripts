# EC2 Kubernetes PostgreSQL Operator Setup

This script sets up a Kubernetes cluster on an EC2 instance and installs the Zalando PostgreSQL Operator along with monitoring tools like Prometheus and Grafana.

## Prerequisites

- An EC2 instance running a Debian-based distribution (e.g., Ubuntu)
- Sudo privileges on the EC2 instance
- Internet access to download necessary packages and dependencies

## Script Overview

The script performs the following steps:

1. **Update and Install Dependencies**: Installs required packages including Docker, Kubernetes components, and AWS CLI.
2. **Install Docker**: Installs and starts Docker.
3. **Install Kubernetes Components**: Installs `kubeadm`, `kubelet`, and `kubectl`.
4. **Initialize Kubernetes Cluster**: Initializes the Kubernetes cluster with Flannel CNI for networking.
5. **Install AWS EBS CSI Driver**: Installs the AWS EBS CSI Driver for persistent storage.
6. **Create StorageClass**: Configures a StorageClass for AWS EBS.
7. **Install Zalando PostgreSQL Operator**: Installs the Zalando PostgreSQL Operator.
8. **Deploy PostgreSQL Cluster**: Deploys a PostgreSQL cluster with persistent storage and high availability.
9. **Install Prometheus and Grafana**: Sets up monitoring with Prometheus and Grafana.
10. **Expose Grafana**: Exposes Grafana via a LoadBalancer.
11. **Install PostgreSQL Exporter**: Installs PostgreSQL metrics exporter for Prometheus.

## Usage

1. **Clone the Repository**:
    ```sh
    git clone <repository-url>
    cd <repository-directory>
    ```

2. **Run the Script**:
    ```sh
    chmod +x Scritps/ec2k8spgoperator.sh
    ./Scritps/ec2k8spgoperator.sh
    ```

## Customization

You can customize the following variables in the script as needed:

- `CLUSTER_NAME`: Name of the PostgreSQL cluster.
- `STORAGE_CLASS_NAME`: Name of the StorageClass.
- `POSTGRESQL_VERSION`: Version of PostgreSQL to deploy.
- `AWS_REGION`: AWS region for the EBS volumes.
- `EBS_VOLUME_TYPE`: Type of EBS volume (e.g., `gp3`).
- `EBS_VOLUME_SIZE`: Size of the EBS volume (e.g., `10Gi`).
- `NAMESPACE`: Kubernetes namespace to deploy resources.

## Monitoring

The script sets up Prometheus and Grafana for monitoring the PostgreSQL cluster. Grafana is exposed via a LoadBalancer service.

## Using the Zalando Operator UI

The Zalando PostgreSQL Operator includes a web-based user interface for managing PostgreSQL clusters. To access the UI:

1. **Port Forwarding**:
    ```sh
    kubectl port-forward svc/postgres-operator-ui 8080:80 -n <namespace>
    ```

2. **Access the UI**:
    Open your web browser and navigate to `http://localhost:8080`.





