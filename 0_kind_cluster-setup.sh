#!/usr/bin/env bash
set -eo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

mkdir -p /state/kube

# 1. Create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  echo -e "${GREEN}Creating local container registry...${NC}"
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi

# 2. Create Kind cluster
if [ ! -f /state/kube/config.yaml ]; then
  echo -e "${GREEN}Creating Kind cluster...${NC}"
  kind create cluster -n workshop --kubeconfig /state/kube/config.yaml --config ./setup/kind/cluster.yaml
fi

# Export kubeconfig for other tools to use
export KUBECONFIG=/state/kube/config.yaml

# Modify your Kubeconfig (/state/kube/config.yaml) to always skip TLS verification: (to use in docker)
sed -i 's|server: https://127.0.0.1|server: https://host.docker.internal|' /state/kube/config.yaml
kubectl config set-cluster kind-workshop --kubeconfig /state/kube/config.yaml --insecure-skip-tls-verify=true

# connect current container to the kind network
container_name="workshop"
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${container_name}")" = 'null' ]; then
  docker network connect "kind" "${container_name}"
fi

# 3. Add the registry config to the nodes
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes -n workshop); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

# 4. Connect the registry to the cluster network if not already connected
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# 5. Document the local registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo ""
echo -e "${GREEN}>>>> Kind cluster created successfully.${NC}"
echo -e "${GREEN}>>>> Use 'kubectl --kubeconfig=/state/kube/config.yaml' for cluster operations${NC}"
echo -e "${GREEN}>>>> Or export KUBECONFIG=/state/kube/config.yaml${NC}"