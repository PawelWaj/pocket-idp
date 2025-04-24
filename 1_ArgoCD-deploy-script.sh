#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================================${NC}"
echo -e "${GREEN}Backstage and ArgoCD Workshop Setup Script${NC}"
echo -e "${BLUE}=========================================================${NC}"

# Check required tools
echo -e "${YELLOW}Checking required tools...${NC}"
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}Kubectl is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Helm is required but not installed. Aborting.${NC}" >&2; exit 1; }
echo -e "${GREEN}All required tools are available.${NC}"

# Configuration
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="2.10.1"
BACKSTAGE_NAMESPACE="backstage"
ARGOCD_PASSWORD="password" # For a workshop, we use a simple password. Change for production.
GITHUB_REPO="https://github.com/PawelWaj/workshop.git" # Your workshop repository
#GITHUB_TOKEN="xxx" # Replace with actual GitHub token

# Set kubeconfig from your existing setup
export KUBECONFIG=/state/kube/config.yaml
echo -e "${YELLOW}Using existing Kind cluster with kubeconfig at: ${KUBECONFIG}${NC}"

# Create namespaces
echo -e "${YELLOW}Creating namespaces...${NC}"
kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ${BACKSTAGE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo -e "${YELLOW}Installing ArgoCD...${NC}"
kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml

# Patch ArgoCD service to use NodePort
echo -e "${YELLOW}Patching ArgoCD service to use NodePort...${NC}"
kubectl patch svc argocd-server -n ${ARGOCD_NAMESPACE} -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "nodePort": 30008}]}}'

# Wait for ArgoCD deployment
echo -e "${YELLOW}Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${ARGOCD_NAMESPACE}
echo -e "${GREEN}ArgoCD deployed successfully.${NC}"

# Get initial ArgoCD admin password and change it to our defined password
echo -e "${YELLOW}Setting ArgoCD admin password...${NC}"
sleep 10 # Give ArgoCD a moment to create the admin secret

# Get the initial admin password
INITIAL_PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Install ArgoCD CLI
echo -e "${YELLOW}Installing ArgoCD CLI...${NC}"
curl -sSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64
chmod +x /tmp/argocd-linux-amd64
 mv /tmp/argocd-linux-amd64 /usr/local/bin/argocd

# Wait for the ArgoCD API to be available
echo -e "${YELLOW}Waiting for ArgoCD API to be available...${NC}"

# Start port forwarding in the background
kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:80 &
PORT_FORWARD_PID=$!

# Give port forwarding time to establish
sleep 5

# Try to login with max attempts
MAX_ATTEMPTS=20
ATTEMPTS=0
PASSWORD_CHANGED=false

until argocd login localhost:8080 --username admin --password "${INITIAL_PASSWORD}" --insecure || [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; do
  ATTEMPTS=$((ATTEMPTS+1))
  echo "Waiting for ArgoCD API... Attempt $ATTEMPTS of $MAX_ATTEMPTS"
  sleep 10
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
  echo -e "${RED}Failed to connect to ArgoCD API after $MAX_ATTEMPTS attempts. Continuing anyway, but password may not be set.${NC}"
else
  echo -e "${GREEN}Successfully connected to ArgoCD API.${NC}"
  
  # Change the password - only do this once
  argocd account update-password --current-password "${INITIAL_PASSWORD}" --new-password "${ARGOCD_PASSWORD}" --insecure
  PASSWORD_CHANGED=true
  echo -e "${GREEN}ArgoCD admin password changed.${NC}"
  
  # Log out and log back in with the new password
 # argocd logout
 # argocd login localhost:8080 --username admin --password "${ARGOCD_PASSWORD}" --insecure
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "GITHUB_TOKEN is not set"
  exit 1
fi

# Add your GitHub repository to ArgoCD using the correct password
echo -e "${YELLOW}Adding your GitHub repository to ArgoCD...${NC}"
if [ "$PASSWORD_CHANGED" = true ]; then
  argocd repo add ${GITHUB_REPO} --username "git" --password "${GITHUB_TOKEN}" --insecure
else
  # If password wasn't changed, try with initial password
  argocd repo add ${GITHUB_REPO} --username "git" --password "${GITHUB_TOKEN}" --insecure || echo -e "${RED}Failed to add repository to ArgoCD.${NC}"
fi

# Kill the port-forwarding process when done
kill $PORT_FORWARD_PID 2>/dev/null || true

# Create ConfigMap for Backstage app-config with in-memory database
echo -e "${YELLOW}Creating ConfigMap for Backstage app-config...${NC}"
cat <<EOF > backstage-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backstage-app-config
  namespace: ${BACKSTAGE_NAMESPACE}
data:
  app-config.yaml: |
    app:
      title: Backstage Workshop
      baseUrl: http://localhost:7007
    
    organization:
      name: Workshop Organization
    
    backend:
      baseUrl: http://localhost:7007
      listen:
        port: 7007
      database:
        client: better-sqlite3
        connection: ':memory:'
      cors:
        origin: http://localhost:7007
        methods: [GET, POST, PUT, DELETE]
        credentials: true
      reading:
        allow:
          - host: raw.githubusercontent.com
      logger:
        level: debug
    
    catalog:
      rules:
        - allow: [Component, System, API, Resource, Location, Template]
      locations:
        - type: url
          target: https://raw.githubusercontent.com/PawelWaj/workshop/main/catalog-info.yaml
        - type: url
          target: https://raw.githubusercontent.com/PawelWaj/workshop/main/template.yaml
        - type: url
          target: https://github.com/PawelWaj/workshop/blob/main/templates/kubernetes-app-template.yaml
          rules:
            - allow: [Template]
    
    integrations:
      github:
        - host: github.com
          token: \${GITHUB_TOKEN}
    
    argocd:
      baseUrl: http://localhost:8080
      username: admin
      password: \${ARGOCD_PASSWORD}
EOF

kubectl apply -f backstage-config.yaml

# Deploy the Backstage instance from iocanel/backstage-docker
echo -e "${YELLOW}Deploying Backstage...${NC}"

cat <<EOF > backstage-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: ${BACKSTAGE_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backstage
  template:
    metadata:
      labels:
        app: backstage
    spec:
      containers:
        - name: backstage
          image: ghcr.io/pawelwaj/backstage/backstage-workshop:latest
          ports:
            - containerPort: 7007
          env:
            - name: NODE_ENV
              value: development
            - name: GITHUB_TOKEN
              value: "${GITHUB_TOKEN}"
            - name: ARGOCD_PASSWORD
              value: "${ARGOCD_PASSWORD}"

          volumeMounts:
            - name: app-config
              mountPath: /app/app-config.yaml
              subPath: app-config.yaml
          resources:
            limits:
              memory: "1Gi"
              cpu: "500m"
            requests:
              memory: "512Mi"
              cpu: "250m"
      volumes:
        - name: app-config
          configMap:
            name: backstage-app-config
---
apiVersion: v1
kind: Service
metadata:
  name: backstage
  namespace: ${BACKSTAGE_NAMESPACE}
spec:
  selector:
    app: backstage
  ports:
    - port: 7007
      targetPort: 7007
      nodePort: 30007
  type: NodePort
EOF

kubectl apply -f backstage-deployment.yaml

echo -e "${YELLOW}Waiting for Backstage to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/backstage -n ${BACKSTAGE_NAMESPACE}
echo -e "${GREEN}Backstage deployed successfully.${NC}"

# Create ArgoCD application using the workshop repository
echo -e "${YELLOW}Creating ArgoCD application using your workshop repository...${NC}"
cat <<EOF > workshop-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: workshop-app
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  source:
    repoURL: ${GITHUB_REPO}
    targetRevision: HEAD
    path: k8s  # Assuming manifests are in the k8s directory
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

kubectl apply -f workshop-app.yaml
echo -e "${GREEN}Workshop application created in ArgoCD.${NC}"

# Create sample application structure in the local filesystem
echo -e "${YELLOW}Creating sample application structure for workshop...${NC}"
mkdir -p workshop-sample/k8s

cat <<EOF > workshop-sample/k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  labels:
    app: sample-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: sample-app
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
spec:
  selector:
    app: sample-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

cat <<EOF > workshop-sample/catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: sample-app
  description: Sample application for workshop
  annotations:
    github.com/project-slug: PawelWaj/workshop
    argocd/app-name: workshop-app
spec:
  type: service
  lifecycle: experimental
  owner: workshop-team
EOF

echo -e "${GREEN}Sample application structure created.${NC}"
echo -e "${YELLOW}You can use this as a reference for your workshop repository.${NC}"

# Instructions for accessing services
echo -e "${BLUE}=========================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}ArgoCD is available at:${NC} http://localhost:8080"
echo -e "${YELLOW}ArgoCD Credentials:${NC}"
echo -e "  Username: admin"
echo -e "  Password: ${ARGOCD_PASSWORD}"
echo -e "${YELLOW}Backstage is available at:${NC} http://localhost:7007"
echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}Workshop Repository Information:${NC}"
echo -e "1. Workshop Repository: ${GITHUB_REPO}"
echo -e "2. For new deployments, create a PR to this repository."
echo -e "3. ArgoCD will automatically sync changes from the repo to the cluster."
echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}Important Notes for Integration:${NC}"
echo -e "1. Replace 'GITHUB_TOKEN' in the .env file with a valid GitHub token."
echo -e "2. Make sure your workshop repository has the following structure:"
echo -e "   - k8s/ directory with Kubernetes manifests"
echo -e "   - catalog-info.yaml for Backstage integration"
echo -e "3. For Backstage to ArgoCD integration, ensure these annotations in catalog-info.yaml:"
echo -e "   annotations:"
echo -e "     github.com/project-slug: PawelWaj/workshop"
echo -e "     argocd/app-name: workshop-app"
echo -e "${BLUE}=========================================================${NC}"