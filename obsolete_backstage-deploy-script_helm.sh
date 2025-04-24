#!/bin/bash
# Deploy Backstage to the Kind cluster using Helm

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure KUBECONFIG is set
if [ -z "${KUBECONFIG}" ]; then
  echo "KUBECONFIG not set. Setting to default location..."
  export KUBECONFIG=/state/kube/config.yaml
fi
export KUBECONFIG=/state/kube/config.yaml
# Set the working directory to setup/backstage
WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/setup/backstage"
mkdir -p "$WORKDIR"  # Ensure the directory exists
cd "$WORKDIR" || { echo "Failed to enter $WORKDIR. Exiting..."; exit 1; }

# Verify connection to the cluster
echo "Verifying connection to the cluster..."
kubectl get nodes || { echo "Failed to connect to the cluster. Check your KUBECONFIG."; exit 1; }

# Create the namespace for Backstage
echo "Creating namespace 'backstage'..."
kubectl create namespace backstage || echo "Namespace 'backstage' already exists."

# Install NGINX Ingress Controller
echo "Installing NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Wait for NGINX Ingress Controller to be ready
echo "Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Add the Backstage Helm repository (if using a public or custom Helm chart)
echo "Adding Backstage Helm repository..."
helm repo add backstage https://backstage.github.io/charts || echo "Backstage Helm repo already added."
helm repo update


# Deploy Backstage using Helm
echo "Deploying Backstage using Helm..."
helm upgrade --install backstage backstage/backstage \
  --namespace backstage 

# Wait for Backstage pods to be ready
echo "Waiting for Backstage pods to be ready..."
kubectl wait --namespace backstage \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=backstage \
  --timeout=300s

# Deploy Backstage using Helm
echo "Upgrade Backstage using Helm..."
helm upgrade --install backstage backstage/backstage \
  --namespace backstage -f /app/setup/backstage/values.yaml

echo ""
echo "Backstage deployment completed!"
echo "You can access Backstage at http://backstage.localhost once all pods are running."
echo ""
echo "Check the status of your deployment:"
echo "kubectl get pods -n backstage"
echo "kubectl get ingress -n backstage -o wide"



# # Update the Backstage deployment with the token
# echo "Updating Backstage deployment with the token..."
# helm upgrade --install backstage backstage/backstage \
#   --namespace backstage \
#   --set-string "backstage.extraEnvVars[0].name=K8S_SA_TOKEN" \
#   --set-string "backstage.extraEnvVars[0].value=$K8S_SA_TOKEN" \
#   --set-string "backstage.appConfig.kubernetes.clusterLocatorMethods[0].clusters[0].serviceAccountToken=$K8S_SA_TOKEN" \
#   -f /app/setup/backstage/values_templates.yaml


  # Run setup script to create ConfigMap and service account token
bash /app/backstage-template.sh

# # Deploy Backstage using Helm with the token from the script
# helm upgrade --install backstage backstage/backstage \
#   --namespace backstage \
#   --set-string "backstage.extraEnvVars[0].name=K8S_SA_TOKEN" \
#   --set-string "backstage.extraEnvVars[0].value=$K8S_SA_TOKEN" \
#   --set-string "backstage.appConfig.kubernetes.clusterLocatorMethods[0].clusters[0].serviceAccountToken=$K8S_SA_TOKEN" \
#   -f /app/setup/backstage/values_templates.yaml