#!/bin/bash
# Deploy Backstage to the Kind cluster

# Make sure KUBECONFIG is set
if [ -z "${KUBECONFIG}" ]; then
  echo "KUBECONFIG not set. Setting to default location..."
  export KUBECONFIG=/state/kube/config.yaml
fi

# Set the working directory to setup/backstage
WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/setup/backstage"
mkdir -p "$WORKDIR"  # Ensure the directory exists
cd "$WORKDIR" || { echo "Failed to enter $WORKDIR. Exiting..."; exit 1; }

# Verify connection to the cluster
echo "Verifying connection to the cluster..."
kubectl get nodes || { echo "Failed to connect to the cluster. Check your KUBECONFIG."; exit 1; }

# Create backstage namespace
echo "Creating backstage namespace..."
kubectl apply -f backstage-namespace.yaml

# Install NGINX Ingress Controller
echo "Installing NGINX Ingress Controller..."
bash nginx-ingress-install.sh

# # Deploy PostgreSQL
# echo "Deploying PostgreSQL..."
# kubectl apply -f backstage-postgres.yaml

# # Wait for PostgreSQL to be ready
# echo "Waiting for PostgreSQL to be ready..."
# kubectl wait --namespace backstage \
#   --for=condition=ready pod \
#   --selector=app=postgres \
#   --timeout=120s || echo "Timeout waiting for PostgreSQL. Continuing anyway..."

# Deploy Backstage
echo "Deploying Backstage..."
kubectl apply -f backstage-deployment.yaml

# Create Ingress
echo "Creating Ingress..."
kubectl apply -f backstage-ingress.yaml

echo ""
echo "Backstage deployment completed!"
echo "You can access Backstage at http://localhost once all pods are running."
echo ""
echo "Check the status of your deployment:"
echo "kubectl get pods -n backstage"
echo "kubectl get ingress -n backstage -o wide"