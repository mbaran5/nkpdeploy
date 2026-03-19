#!/bin/bash

# --- ANSI Color Codes ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}Performing Pre-flight checks...${NC}"

# 1. SYSTEM-WIDE CGROUP DELEGATION
GLOBAL_DELEGATE_DIR="/etc/systemd/system/user@.service.d"
GLOBAL_DELEGATE_CONF="$GLOBAL_DELEGATE_DIR/delegate.conf"

if [[ ! -f "$GLOBAL_DELEGATE_CONF" ]]; then
    echo -e "${YELLOW}--> Global cgroup delegation missing. Applying fix...${NC}"
    sudo mkdir -p "$GLOBAL_DELEGATE_DIR"
    echo -e "[Service]\nDelegate=yes" | sudo tee "$GLOBAL_DELEGATE_CONF" > /dev/null
    sudo systemctl daemon-reload
    echo -e "${RED}=======================================================${NC}"
    echo -e "${RED}SYSTEM CHANGE APPLIED: REBOOT REQUIRED${NC}"
    echo -e "${YELLOW}The kernel requires a reboot to delegate cgroup control.${NC}"
    echo -e "Please run: ${CYAN}sudo reboot${NC}"
    echo -e "${RED}=======================================================${NC}"
    exit 1
fi

# VERIFY IF ACTIVE
if ! systemctl show user@$(id -u).service --property=Delegate | grep -q "Delegate=yes"; then
    echo -e "${RED}=======================================================${NC}"
    echo -e "${RED}ERROR: Cgroup delegation is configured but NOT ACTIVE.${NC}"
    echo -e "${YELLOW}A reboot is required to activate these kernel permissions.${NC}"
    echo -e "Please run: ${CYAN}sudo reboot${NC}"
    echo -e "${RED}=======================================================${NC}"
    exit 1
fi
echo -e "${GREEN}--> Cgroup delegation verified and ACTIVE.${NC}"

# 2. FIND OR DOWNLOAD BUNDLE
BUNDLE_FILE=$(ls nkp-bundle_v*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$BUNDLE_FILE" ]; then
    echo -e "${YELLOW}NKP Bundle not found in current directory.${NC}"
    echo -ne "${CYAN}Please paste the full Nutanix Download URL: ${NC}"
    read -r RAW_URL
    [[ -z "$RAW_URL" ]] && exit 1
    BUNDLE_FILE=$(basename "${RAW_URL%%\?*}")
    curl -kL -o "$BUNDLE_FILE" "$RAW_URL"
fi

# 3. VERSION & EXTRACTION
VERSION_WITH_V=$(echo "$BUNDLE_FILE" | sed -E 's/.*bundle_(v[0-9]+\.[0-9]+\.[0-9]+).*/\1/')
TARGET_DIR="${BUNDLE_FILE%.tar.gz}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${CYAN}Extracting $BUNDLE_FILE into ./$TARGET_DIR...${NC}"
    mkdir -p "$TARGET_DIR"
    tar -axf "$BUNDLE_FILE" -C "$TARGET_DIR" --strip-components=1
fi

# 4. INSTALL BINARIES TO /usr/local/bin
echo -e "${CYAN}Installing nkp and kubectl to /usr/local/bin...${NC}"
sudo cp "./$TARGET_DIR/cli/nkp" /usr/local/bin/nkp
sudo cp "./$TARGET_DIR/kubectl" /usr/local/bin/kubectl
sudo chmod +x /usr/local/bin/nkp /usr/local/bin/kubectl
echo -e "${GREEN}--> Binaries installed successfully.${NC}"

# Define Bundle Paths
KOMMANDER_BUNDLE="./$TARGET_DIR/container-images/kommander-image-bundle-${VERSION_WITH_V}.tar"
KONVOY_BUNDLE="./$TARGET_DIR/container-images/konvoy-image-bundle-${VERSION_WITH_V}.tar"
BUNDLE_FLAGS="--bundle ${KOMMANDER_BUNDLE},${KONVOY_BUNDLE}"

# 5. USER INPUTS
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${CYAN}      NKP Version Detected: ${GREEN}${VERSION_WITH_V}${NC}"
echo -e "${YELLOW}=======================================================${NC}"

read -p "Prism Central Endpoint (IP): " PC_ENDPOINT
read -p "Prism Username: " NUTANIX_USER
echo -ne "${YELLOW}Prism Password: ${NC}"
read -s NUTANIX_PASSWORD
echo -e "\n"
read -p "NKP Cluster Name: " CLUSTER_NAME
read -p "Control Plane VIP: " VIP
read -p "VM Image Name (.qcow2): " VM_IMAGE
read -p "AHV Cluster Name: " AHV_CLUSTER
read -p "Network Name: " NETWORK
read -p "Storage Container: " STORAGE
read -p "LB IP Range (x.x.x.x-y.y.y.y): " LB_RANGE

# 6. FINAL DEPLOYMENT SUMMARY
clear
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}           FINAL DEPLOYMENT SUMMARY                    ${NC}"
echo -e "${YELLOW}=======================================================${NC}"
printf "${CYAN}%-25s${NC} : %s\n" "NKP Version" "$VERSION_WITH_V"
printf "${CYAN}%-25s${NC} : %s\n" "Cluster Name" "$CLUSTER_NAME"
printf "${CYAN}%-25s${NC} : %s\n" "PC Endpoint" "$PC_ENDPOINT"
printf "${CYAN}%-25s${NC} : %s\n" "Control Plane VIP" "$VIP"
printf "${CYAN}%-25s${NC} : %s\n" "VM Image Name" "$VM_IMAGE"
printf "${CYAN}%-25s${NC} : %s\n" "AHV Cluster Name" "$AHV_CLUSTER"
printf "${CYAN}%-25s${NC} : %s\n" "AHV Network Name" "$NETWORK"
printf "${CYAN}%-25s${NC} : %s\n" "Storage Container" "$STORAGE"
printf "${CYAN}%-25s${NC} : %s\n" "Load Balancer Range" "$LB_RANGE"
echo -e "${YELLOW}=======================================================${NC}"

read -p "Proceed with deployment? (y/n) > " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && exit 0

# 7. DEPLOYMENT
export NUTANIX_USER
export NUTANIX_PASSWORD
export NUTANIX_ENDPOINT="https://${PC_ENDPOINT}:9440"

# Standard kubeconfig name in current dir
export KUBECONFIG="$(pwd)/${CLUSTER_NAME}.conf"

echo -e "${GREEN}Starting Deployment...${NC}"
# nkp is now in /usr/local/bin, so we call it directly
nkp create cluster nutanix \
  $BUNDLE_FLAGS \
  --cluster-name "${CLUSTER_NAME}" \
  --endpoint "${NUTANIX_ENDPOINT}" \
  --insecure \
  --control-plane-prism-element-cluster "${AHV_CLUSTER}" \
  --worker-prism-element-cluster "${AHV_CLUSTER}" \
  --control-plane-subnets "${NETWORK}" \
  --worker-subnets "${NETWORK}" \
  --vm-image "${VM_IMAGE}" \
  --control-plane-endpoint-ip "${VIP}" \
  --csi-storage-container "${STORAGE}" \
  --kubernetes-service-load-balancer-ip-range "${LB_RANGE}" \
  --control-plane-replicas 3 \
  --worker-replicas 2 \
  --self-managed

echo -e "${GREEN}Deployment finished.${NC}"
echo -e "${CYAN}Access your cluster with: export KUBECONFIG=$(pwd)/${CLUSTER_NAME}.conf${NC}"fi
echo -e "${GREEN}--> Cgroup delegation verified and ACTIVE.${NC}"

# 2. FIND OR DOWNLOAD BUNDLE
BUNDLE_FILE=$(ls nkp-bundle_v*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$BUNDLE_FILE" ]; then
    echo -e "${YELLOW}NKP Bundle not found in current directory.${NC}"
    echo -ne "${CYAN}Please paste the full Nutanix Download URL: ${NC}"
    read -r RAW_URL
    [[ -z "$RAW_URL" ]] && exit 1
    BUNDLE_FILE=$(basename "${RAW_URL%%\?*}")
    curl -L -o "$BUNDLE_FILE" "$RAW_URL"
fi

# 3. VERSION & EXTRACTION
VERSION_WITH_V=$(echo "$BUNDLE_FILE" | sed -E 's/.*bundle_(v[0-9]+\.[0-9]+\.[0-9]+).*/\1/')
TARGET_DIR="${BUNDLE_FILE%.tar.gz}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${CYAN}Extracting $BUNDLE_FILE...${NC}"
    mkdir -p "$TARGET_DIR"
    tar -axf "$BUNDLE_FILE" -C "$TARGET_DIR" --strip-components=1
    chmod +x "./$TARGET_DIR/cli/nkp" "./$TARGET_DIR/kubectl"
fi

# Define Paths
NKP_BINARY="./$TARGET_DIR/cli/nkp"
KOMMANDER_BUNDLE="./$TARGET_DIR/container-images/kommander-image-bundle-${VERSION_WITH_V}.tar"
KONVOY_BUNDLE="./$TARGET_DIR/container-images/konvoy-image-bundle-${VERSION_WITH_V}.tar"
BUNDLE_FLAGS="--bundle ${KOMMANDER_BUNDLE},${KONVOY_BUNDLE}"

# 4. USER INPUTS
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${CYAN}      NKP Version: ${GREEN}${VERSION_WITH_V}${NC}"
echo -e "${YELLOW}=======================================================${NC}"

read -p "Prism Central Endpoint (IP): " PC_ENDPOINT
read -p "Prism Username: " NUTANIX_USER
echo -ne "${YELLOW}Prism Password: ${NC}"
read -s NUTANIX_PASSWORD
echo -e "\n"
read -p "NKP Cluster Name: " CLUSTER_NAME
read -p "Control Plane VIP: " VIP
read -p "VM Image Name (.qcow2): " VM_IMAGE
read -p "AHV Cluster Name: " AHV_CLUSTER
read -p "Network Name: " NETWORK
read -p "Storage Container: " STORAGE
read -p "LB IP Range (x.x.x.x-y.y.y.y): " LB_RANGE

# 5 --- Version Validation ---
# A. Fetch Prism Central version and strip "pc." prefix
PC_RAW=$(curl -s -k -u "$NUTANIX_USER:$NUTANIX_PASSWORD" "https://${PC_ENDPOINT}:9440/api/nutanix/v2.0/cluster" | jq -r '.version // empty')
PC_VERSION=${PC_RAW#pc.}

# B. Find UUID for the specific AHV cluster name provided by user
C_UUID=$(curl -s -k -u "$NUTANIX_USER:$NUTANIX_PASSWORD" -X POST "https://${PC_ENDPOINT}:9440/api/nutanix/v3/clusters/list" \
  -H "Content-Type: application/json" -d '{"kind": "cluster"}' \
  | jq -r --arg NAME "$AHV_CLUSTER" '.entities[] | select(.status.name == $NAME) | .metadata.uuid // empty')

# C. Fetch AOS version using the discovered UUID
AOS_VERSION=$(curl -s -k -u "$NUTANIX_USER:$NUTANIX_PASSWORD" -X GET "https://${PC_ENDPOINT}:9440/api/nutanix/v3/clusters/$C_UUID" \
  | jq -r '.status.resources.config.software_map.NOS.version // empty')

# D Compare versions (Must be > 7.3)
# Returns 0 if $1 > $2
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

if [[ -z "$PC_VERSION" || -z "$AOS_VERSION" ]]; then
    echo -e "${RED}ERROR: Could not retrieve Nutanix versions. Check credentials or AHV Cluster Name.${NC}"
    exit 1
fi

if ! version_gt "$PC_VERSION" "7.3" || ! version_gt "$AOS_VERSION" "7.3"; then
    echo -e "${RED}ERROR: Installation halted. Incompatible versions detected.${NC}"
    echo -e "Required: > 7.3 | Detected: PC $PC_RAW, AOS $AOS_VERSION"
    exit 1
fi

# 6. FINAL DEPLOYMENT SUMMARY (Restored)
clear
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}           FINAL DEPLOYMENT SUMMARY                    ${NC}"
echo -e "${YELLOW}=======================================================${NC}"
printf "${CYAN}%-25s${NC} : %s\n" "NKP Version" "$VERSION_WITH_V"
printf "${CYAN}%-25s${NC} : %s\n" "Prism Central Version" "$PC_RAW"
printf "${CYAN}%-25s${NC} : %s\n" "AOS Version" "$AOS_VERSION"
printf "${CYAN}%-25s${NC} : %s\n" "Cluster Name" "$CLUSTER_NAME"
printf "${CYAN}%-25s${NC} : %s\n" "PC Endpoint" "$PC_ENDPOINT"
printf "${CYAN}%-25s${NC} : %s\n" "Control Plane VIP" "$VIP"
printf "${CYAN}%-25s${NC} : %s\n" "VM Image Name" "$VM_IMAGE"
printf "${CYAN}%-25s${NC} : %s\n" "AHV Cluster Name" "$AHV_CLUSTER"
printf "${CYAN}%-25s${NC} : %s\n" "AHV Network Name" "$NETWORK"
printf "${CYAN}%-25s${NC} : %s\n" "Storage Container" "$STORAGE"
printf "${CYAN}%-25s${NC} : %s\n" "Load Balancer Range" "$LB_RANGE"
echo -e "${YELLOW}=======================================================${NC}"

read -p "Proceed with deployment? (y/n) > " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && exit 0

# 7. DEPLOYMENT
export NUTANIX_USER
export NUTANIX_PASSWORD
export NUTANIX_ENDPOINT="https://${PC_ENDPOINT}:9440"

echo -e "${GREEN}Starting Deployment...${NC}"
$NKP_BINARY create cluster nutanix \
  $BUNDLE_FLAGS \
  --cluster-name "${CLUSTER_NAME}" \
  --endpoint "${NUTANIX_ENDPOINT}" \
  --insecure \
  --control-plane-prism-element-cluster "${AHV_CLUSTER}" \
  --worker-prism-element-cluster "${AHV_CLUSTER}" \
  --control-plane-subnets "${NETWORK}" \
  --worker-subnets "${NETWORK}" \
  --vm-image "${VM_IMAGE}" \
  --control-plane-endpoint-ip "${VIP}" \
  --csi-storage-container "${STORAGE}" \
  --kubernetes-service-load-balancer-ip-range "${LB_RANGE}" \
  --control-plane-replicas 3 \
  --worker-replicas 2 \
  --self-managed
