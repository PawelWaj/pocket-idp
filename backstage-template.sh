#!/bin/bash
# Create ConfigMap for Backstage templates
# Ensure KUBECONFIG is set
echo "start second script with backstage template"
if [ -z "${KUBECONFIG}" ]; then
  echo "KUBECONFIG not set. Setting to default location..."
  export KUBECONFIG=/state/kube/config.yaml
fi
# Create the template content
cat <<EOF > /tmp/kind-deployment.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: kind-deployment
  title: Kind Cluster Deployment
  description: Deploy an application to your Kind cluster
  tags:
    - kubernetes
    - kind
spec:
  owner: platform-team
  type: service
  parameters:
    - title: Application Information
      required:
        - component_id
        - image
      properties:
        component_id:
          title: Application Name
          type: string
          description: Name for your application
          pattern: '^[a-z0-9]+(-[a-z0-9]+)*$'
        image:
          title: Docker Image
          type: string
          description: Docker image to deploy (e.g., nginx:latest)
        namespace:
          title: Kubernetes Namespace
          type: string
          description: Namespace to deploy to
          default: default
        replicas:
          title: Replicas
          type: number
          description: Number of replicas
          default: 1
  steps:
    - id: create-namespace
      name: Create Namespace
      action: kubernetes:apply
      input:
        manifest: |
          apiVersion: v1
          kind: Namespace
          metadata:
            name: \${{ parameters.namespace }}
    - id: create-kubernetes-resources
      name: Create Kubernetes Resources
      action: kubernetes:apply
      input:
        manifest: |
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: \${{ parameters.component_id }}
            namespace: \${{ parameters.namespace }}
          spec:
            replicas: \${{ parameters.replicas }}
            selector:
              matchLabels:
                app: \${{ parameters.component_id }}
            template:
              metadata:
                labels:
                  app: \${{ parameters.component_id }}
              spec:
                containers:
                  - name: \${{ parameters.component_id }}
                    image: \${{ parameters.image }}
                    ports:
                      - containerPort: 80
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: \${{ parameters.component_id }}
            namespace: \${{ parameters.namespace }}
          spec:
            selector:
              app: \${{ parameters.component_id }}
            ports:
              - port: 80
                targetPort: 80
          ---
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: \${{ parameters.component_id }}
            namespace: \${{ parameters.namespace }}
            annotations:
              kubernetes.io/ingress.class: nginx
          spec:
            rules:
              - host: \${{ parameters.component_id }}.localhost
                http:
                  paths:
                    - path: /
                      pathType: Prefix
                      backend:
                        service:
                          name: \${{ parameters.component_id }}
                          port:
                            number: 80
    - id: register
      name: Register Application
      action: catalog:register
      input:
        catalogInfoContent: |
          apiVersion: backstage.io/v1alpha1
          kind: Component
          metadata:
            name: \${{ parameters.component_id }}
            annotations:
              kubernetes.io/namespace: \${{ parameters.namespace }}
          spec:
            type: service
            lifecycle: production
            owner: user:guest
  output:
    links:
      - title: View in catalog
        icon: catalog 
        entityRef: \${{ steps.register.output.entityRef }}
      - title: Open application
        url: http://\${{ parameters.component_id }}.localhost
EOF

# Create ConfigMap in the backstage namespace
kubectl create namespace backstage 2>/dev/null || true
kubectl create configmap backstage-templates --from-file=kind-deployment.yaml=/tmp/kind-deployment.yaml -n backstage

# Set up service account for Backstage
kubectl create serviceaccount backstage -n backstage 2>/dev/null || true
kubectl create clusterrolebinding backstage-admin --clusterrole=cluster-admin --serviceaccount=backstage:backstage 2>/dev/null || true

# Create the token
K8S_SA_TOKEN=$(kubectl create token backstage -n backstage)       
export $K8S_SA_TOKEN
# Export the token for Helm
echo "K8S_SA_TOKEN=$K8S_SA_TOKEN"

# Deploy Backstage using Helm with the token from the script
helm upgrade --install backstage backstage/backstage \
  --namespace backstage \
  --set-string "backstage.extraEnvVars[0].name=K8S_SA_TOKEN" \
  --set-string "backstage.extraEnvVars[0].value=$K8S_SA_TOKEN" \
  --set-string "backstage.appConfig.kubernetes.clusterLocatorMethods[0].clusters[0].serviceAccountToken=$K8S_SA_TOKEN" \
  -f /app/setup/backstage/values_templates.yaml

# Clean up
rm /tmp/kind-deployment.yaml