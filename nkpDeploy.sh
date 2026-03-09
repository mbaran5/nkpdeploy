#!/bin/bash

# --- ANSI Color Codes ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check for required binaries
check_dependencies() {
    local dependencies=("kubectl" "curl" "tar")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}Error: Required binary '$dep' is not installed.${NC}"
            exit 1
        fi
    done
}

# 1. DOWNLOAD LOGIC
# Bypasses "File name too long" by stripping the URL token
handle_missing_bundle() {
    echo -e "${YELLOW}NKP Bundle not found in current directory.${NC}"
    echo -ne "${CYAN}Please paste the full Nutanix Download URL: ${NC}"
    read RAW_URL

    # Extract clean filename (e.g., nkp-bundle_v2.17.0_linux_amd64.tar.gz)
    CLEAN_NAME=$(basename "${RAW_URL%%\?*}")
    
    echo -e "${CYAN}Downloading $CLEAN_NAME...${NC}"
    curl -L -o "$CLEAN_NAME" "$RAW_URL"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed.${NC}"
        exit 1
    fi
    echo "$CLEAN_NAME"
}

# 2. EXTRACTION LOGIC
# Extracts into a folder named exactly after the bundle
handle_extraction() {
    local bundle=$1
    local target_dir="${bundle%.tar.gz}"
    
    echo -e "${CYAN}Extracting $bundle into ./$target_dir...${NC}"
    mkdir -p "$target_dir"
    tar -axf "$bundle" -C "$target_dir" --strip-components=1
    
    if [ $? -eq 0 ]; then
        chmod +x "./$target_dir/cli/nkp"
        echo -e "${GREEN}--> Extraction complete.${NC}"
    else
        echo -e "${RED}--> Extraction failed.${NC}"
        exit 1
    fi
}

# 3. ASSET SETUP
setup_assets() {
    local bundle_file=$(ls nkp-bundle_v*.tar.gz 2>/dev/null | head -n 1)
    
    if [ -z "$bundle_file" ]; then
        bundle_file=$(handle_missing_bundle)
    fi

    local target_dir="${bundle_file%.tar.gz}"

    if [[ ! -d "$target_dir" ]]; then
        handle_extraction "$bundle_file"
    fi

    # Extract version for the bundle flags
    local version=$(echo "$(basename "$bundle_file")" | sed -E 's/.*bundle_(v[0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    local dir_ver="${version#v}"

    # Set Global Variables for the create command
    NKP_BINARY="./$target_dir/cli/nkp"
    BUNDLE_FLAGS="--bundle ./$target_dir/container-images/kommander-image-bundle-${dir_ver}.tar,./$target_dir/container-images/konvoy-image-bundle-${dir_ver}.tar"
    echo "$version"
}

# 4. LB RANGE VALIDATION
validate_lb_range() {
    local range_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}-([0-9]{1,3}\.){3}[0-9]{1,3}$"
    [[ $1 =~ $range_regex ]]
}

# --- START FLOW ---
check_dependencies
VERSION=$(setup_assets)

echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}      NKP Bundle Deployment (Auto-Setup)               ${NC}"
echo -e "${CYAN}      Version: ${GREEN}${VERSION}${NC}"
echo -e "${YELLOW}=======================================================${NC}"

# Nutanix Connection Info
read -p "Prism Central Endpoint (IP): " PC_ENDPOINT
read -p "Prism Username: " NUTANIX_USER
echo -ne "${YELLOW}Prism Password: ${NC}"
read -s NUTANIX_PASSWORD
echo -e "\n"

read -p "NKP Cluster Name: " CLUSTER_NAME
read -p "Control Plane VIP: " VIP

while true; do
    read -p "VM Image Name (.qcow2): " VM_IMAGE
    [[ "$VM_IMAGE" == *.qcow2 ]] && break
    echo -e "${RED}Error: Must end in .qcow2${NC}"
done

read -p "AHV Cluster Name: " AHV_CLUSTER
read -p "Network Name: " NETWORK
read -p "Storage Container: " STORAGE

while true; do
    read -p "LB IP Range (x.x.x.x-y.y.y.y): " LB_RANGE
    validate_lb_range "$LB_RANGE" && break
    echo -e "${RED}Invalid format.${NC}"
done

# Final Confirmation
clear
echo -e "${YELLOW}READY TO DEPLOY: $CLUSTER_NAME${NC}"
echo -e "Binary:  $NKP_BINARY"
echo -e "Bundles: $BUNDLE_FLAGS"
read -p "Press [Enter] to start..."

export NUTANIX_USER
export NUTANIX_PASSWORD
export NUTANIX_ENDPOINT="https://${PC_ENDPOINT}:9440"

# Execute Deployment
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
