#!/bin/bash

# Define colors for the summary screen
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Prompt user for inputs
echo "Please provide the following deployment details:"
read -p "Kubeconfig File Path : " KUBECONFIG_PATH
read -p "NFS Path             : " NFS_PATH
read -p "NFS Server           : " NFS_SERVER
read -p "DockerHub Username   : " DOCKER_USER
read -s -p "DockerHub PAT        : " DOCKER_PAT
echo "" # Add a newline after the silent PAT prompt
echo ""

# Display color-coded summary screen
echo -e "${YELLOW}========================================================================${NC}"
echo -e "${YELLOW}                        FINAL DEPLOYMENT SUMMARY                        ${NC}"
echo -e "${YELLOW}========================================================================${NC}"
printf "${CYAN}%-22s${NC} : %s\n" "Kubeconfig Path" "$KUBECONFIG_PATH"
printf "${CYAN}%-22s${NC} : %s\n" "NFS Path" "$NFS_PATH"
printf "${CYAN}%-22s${NC} : %s\n" "NFS Server" "$NFS_SERVER"
printf "${CYAN}%-22s${NC} : %s\n" "DockerHub Username" "$DOCKER_USER"
printf "${CYAN}%-22s${NC} : %s\n" "DockerHub PAT" "********"
echo -e "${YELLOW}========================================================================${NC}"

# Prompt for confirmation
read -p "Proceed with deployment? (y/n) > " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Deployment cancelled."
    exit 1
fi

echo ""
echo "Deploying Prerequisites..."

# Set the KUBECONFIG context for the current script execution
export KUBECONFIG="$KUBECONFIG_PATH"

# 1. Apply the StorageClass using a heredoc
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nai-nfs-storage
parameters:
  nfsPath: $NFS_PATH
  nfsServer: $NFS_SERVER
  storageType: NutanixFiles
provisioner: csi.nutanix.com
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

# 2. Create the namespaces
kubectl create namespace nai-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace envoy-gateway-system --dry-run=client -o yaml | kubectl apply -f -

# 3. Apply the docker-registry secrets
kubectl -n nai-system create secret docker-registry nai-regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="$DOCKER_USER" \
  --docker-password="$DOCKER_PAT" \
  --docker-email="$DOCKER_USER" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n envoy-gateway-system create secret docker-registry nai-regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="$DOCKER_USER" \
  --docker-password="$DOCKER_PAT" \
  --docker-email="$DOCKER_USER" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Prerequisites completed successfully! Continue the install from the NKP Application Store"
