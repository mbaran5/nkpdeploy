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

# 1. Attempt the copy and chmod
# We use '&&' to ensure chmod only runs if the copy worked
if sudo cp "./$TARGET_DIR/cli/nkp" /usr/local/bin/nkp && \
   sudo cp "./$TARGET_DIR/kubectl" /usr/local/bin/kubectl && \
   sudo chmod +x /usr/local/bin/nkp /usr/local/bin/kubectl; then
    
    # 2. Final Verification: Check if the files actually exist and are executable
    if [[ -x "/usr/local/bin/nkp" ]] && [[ -x "/usr/local/bin/kubectl" ]]; then
        echo -e "${GREEN}--> Binaries installed successfully.${NC}"
    else
        echo -e "${RED}Error: Files copied but permission check failed.${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: Failed to install binaries. Check sudo permissions or source paths.${NC}"
    exit 1
fi

# Define Bundle Paths
KOMMANDER_BUNDLE="./$TARGET_DIR/container-images/kommander-image-bundle-${VERSION_WITH_V}.tar"
KONVOY_BUNDLE="./$TARGET_DIR/container-images/konvoy-image-bundle-${VERSION_WITH_V}.tar"
BUNDLE_FLAGS="--bundle ${KOMMANDER_BUNDLE},${KONVOY_BUNDLE}"

# Helper: Convert IP to a number for comparison
ip2int() {
    local a b c d
    IFS=. read -r a b c d <<< "$1"
    echo "$(( (a << 24) + (b << 16) + (c << 8) + d ))"
}

# Helper: Check if an IP is in the same /24 subnet (Common for NKP)
# If you use different CIDRs, let me know!
is_in_same_subnet() {
    local ip1=$1
    local ip2=$2
    # Masks to the first 3 octets (255.255.255.0)
    [[ "${ip1%.*}" == "${ip2%.*}" ]]
}

get_input() {
    local prompt=$1
    local var_name=$2
    local mode=$3 # "lowercase", "ip", or "range"
    local temp_val=""

    while true; do
        read -p "$prompt" temp_val
        
        # 1. Check if empty
        if [[ -z "$temp_val" ]]; then
            echo -e "${RED}Error: This field cannot be empty.${NC}"
            continue
        fi

        # 2. Lowercase Validation
        if [[ "$mode" == "lowercase" ]] && [[ "$temp_val" =~ [A-Z] ]]; then
            echo -e "${RED}Error: Cluster Name must be lowercase only.${NC}"
            continue
        fi

        # 3. IP Range & Subnet Validation
        if [[ "$mode" == "range" ]]; then
            # Regex for x.x.x.x-y.y.y.y
            if [[ ! "$temp_val" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}-([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                echo -e "${RED}Error: Format must be x.x.x.x-y.y.y.y${NC}"
                continue
            fi

            # Extract start IP of the range
            local range_start=$(echo "$temp_val" | cut -d'-' -f1)
            if ! is_in_same_subnet "$VIP" "$range_start"; then
                echo -e "${RED}Error: LB Range must be in the same subnet as VIP ($VIP).${NC}"
                continue
            fi
        fi

        eval "$var_name=\"$temp_val\""
        break
    done
}

# 5. USER INPUTS
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${CYAN}      NKP Version Detected: ${GREEN}${VERSION_WITH_V}${NC}"
echo -e "${YELLOW}=======================================================${NC}"

get_input "Prism Central Endpoint (IP): " PC_ENDPOINT
get_input "Prism Username: " NUTANIX_USER

# Password loop
while [[ -z "$NUTANIX_PASSWORD" ]]; do
    echo -ne "${YELLOW}Prism Password: ${NC}"
    read -s NUTANIX_PASSWORD
    echo -e "\n"
done

get_input "NKP Cluster Name (lowercase only): " CLUSTER_NAME "lowercase"
get_input "Control Plane VIP: " VIP
get_input "VM Image Name (.qcow2): " VM_IMAGE
get_input "AHV Cluster Name: " AHV_CLUSTER
get_input "Network Name: " NETWORK
get_input "Storage Container: " STORAGE

# This will now validate format AND subnet alignment with $VIP
get_input "LB IP Range (x.x.x.x-y.y.y.y): " LB_RANGE "range"

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

# 6. FINAL DEPLOYMENT SUMMARY 
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

# Standard kubeconfig name in current dir
export KUBECONFIG="$(pwd)/${CLUSTER_NAME}.conf"

echo -e "${GREEN}Starting Deployment...${NC}"
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
echo -e "${CYAN}Access your cluster with: export KUBECONFIG=$(pwd)/${CLUSTER_NAME}.conf${NC}"
