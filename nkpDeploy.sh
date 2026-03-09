#!/bin/bash

# --- ANSI Color Codes ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check for required binaries
check_dependencies() {
    local dependencies=("kubectl" "curl")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}Error: Required binary '$dep' is not installed.${NC}"
            exit 1
        fi
    done
}

# Function to Detect NKP Version from the tarball in ~
detect_nkp_version() {
    local bundle_file=$(ls ~/nkp-bundle_v*.tar.gz 2>/dev/null | head -n 1)
    
    if [ -z "$bundle_file" ]; then
        echo -e "${RED}Error: NKP bundle file not found in ~. Expected: nkp-bundle_vX.Y.Z_linux_amd64.tar.gz${NC}"
        exit 1
    fi

    # Extract version (e.g., v2.17.0)
    local version=$(echo "$(basename "$bundle_file")" | sed -E 's/.*bundle_(v[0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    echo "$version"
}

# Function to Verify Local Binary and Bundle Files Exist
verify_assets() {
    local dir_ver=$1
    local binary="./nkp-${dir_ver}/cli/nkp"
    local kommander_path="./nkp-${dir_ver}/container-images/kommander-image-bundle-${dir_ver}.tar"
    local konvoy_path="./nkp-${dir_ver}/container-images/konvoy-image-bundle-${dir_ver}.tar"
    local missing=0

    echo -e "${CYAN}Verifying local assets in ./nkp-${dir_ver}/...${NC}"

    if [[ ! -x "$binary" ]]; then
        echo -e "${RED}--> Missing or Non-Executable: $binary${NC}"
        missing=1
    fi
    if [[ ! -f "$kommander_path" ]]; then
        echo -e "${RED}--> Missing: $kommander_path${NC}"
        missing=1
    fi
    if [[ ! -f "$konvoy_path" ]]; then
        echo -e "${RED}--> Missing: $konvoy_path${NC}"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        echo -e "${RED}Error: Required files not found. Ensure extraction to ./nkp-${dir_ver} is complete.${NC}"
        exit 1
    fi
    echo -e "${GREEN}--> All assets verified.${NC}"
}

# Function to validate the LB Range
validate_lb_range() {
    local range=$1
    local range_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}-([0-9]{1,3}\.){3}[0-9]{1,3}$"
    if [[ ! $range =~ $range_regex ]]; then
        echo -e "${RED}--> Error: Invalid format! Use: x.x.x.x-y.y.y.y${NC}"
        return 1
    fi
    return 0
}

# --- Initialization ---
check_dependencies
NKP_VERSION=$(detect_nkp_version)
DIR_VERSION="${NKP_VERSION#v}" # Strip 'v' for directory naming (e.g., 2.17.0)

# Verify extraction exists before asking for input
verify_assets "$DIR_VERSION"

# Construct Bundle Flags and Binary Path
NKP_BINARY="./nkp-${DIR_VERSION}/cli/nkp"
BUNDLE_FLAGS="--bundle ./nkp-${DIR_VERSION}/container-images/kommander-image-bundle-${DIR_VERSION}.tar,./nkp-${DIR_VERSION}/container-images/konvoy-image-bundle-${DIR_VERSION}.tar"

echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}      NKP Nutanix Bundle Deployment Initializer        ${NC}"
echo -e "${CYAN}      Version Detected: ${GREEN}${NKP_VERSION}${NC}"
echo -e "${YELLOW}=======================================================${NC}"

# 1. Nutanix Connection Info
read -p "Prism Central Endpoint (IP only): " PC_ENDPOINT
read -p "Prism Username: " NUTANIX_USER
echo -ne "${YELLOW}Prism Password: ${NC}"
read -s NUTANIX_PASSWORD
echo -e "\n"

# 2. Cluster Configuration
read -p "NKP Cluster Name: " CLUSTER_NAME
read -p "Control Plane VIP: " VIP

while true; do
    read -p "VM Image Name (must include .qcow2): " VM_IMAGE
    [[ "$VM_IMAGE" == *.qcow2 ]] && break
    echo -e "${RED}--> Error: Filename must end with '.qcow2'.${NC}"
done

read -p "AHV Cluster Name (Prism Element): " AHV_CLUSTER
read -p "AHV Network Name: " NETWORK
read -p "Storage Container Name: " STORAGE

while true; do
    read -p "Load Balancer IP Range (x.x.x.x-y.y.y.y): " LB_RANGE
    validate_lb_range "$LB_RANGE" && break
done

# --- FINAL CONFIRMATION ---
clear
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}           FINAL DEPLOYMENT SUMMARY                    ${NC}"
echo -e "${YELLOW}=======================================================${NC}"
printf "${CYAN}%-25s${NC} : %s\n" "NKP Version" "$NKP_VERSION"
printf "${CYAN}%-25s${NC} : %s\n" "Cluster Name" "$CLUSTER_NAME"
printf "${CYAN}%-25s${NC} : %s\n" "PC Endpoint" "$PC_ENDPOINT"
echo -e "-------------------------------------------------------"
printf "${CYAN}%-25s${NC} : %s\n" "Control Plane VIP" "$VIP"
printf "${CYAN}%-25s${NC} : %s\n" "VM Image Name" "$VM_IMAGE"
printf "${CYAN}%-25s${NC} : %s\n" "AHV Cluster Name" "$AHV_CLUSTER"
printf "${CYAN}%-25s${NC} : %s\n" "AHV Network Name" "$NETWORK"
printf "${CYAN}%-25s${NC} : %s\n" "Load Balancer Range" "$LB_RANGE"
echo -e "${YELLOW}=======================================================${NC}"

echo -e "${YELLOW}Proceed with deployment? (y/n)${NC}"
read -p "> " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 0
fi

# Export credentials for the binary
export NUTANIX_USER
export NUTANIX_PASSWORD
export NUTANIX_ENDPOINT="https://${PC_ENDPOINT}:9440"

echo -e "${GREEN}Starting NKP creation using local assets...${NC}"

# Run the deployment using the local binary and bundles
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
