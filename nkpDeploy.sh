#!/bin/bash

# ANSI Color Codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check for required binaries
check_dependencies() {
    local dependencies=("nkp" "kubectl" "curl")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}Error: Required binary '$dep' is not installed.${NC}"
            exit 1
        fi
    done
}

# Function to validate Docker Hub credentials
check_docker_creds() {
    local user=$1
    local pass=$2
    echo -e "${CYAN}Verifying Docker Hub credentials...${NC}"
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" -u "$user:$pass" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview:pull")

    if [ "$response" == "200" ]; then
        echo -e "${GREEN}--> Docker Hub authentication successful!${NC}"
        return 0
    else
        echo -e "${RED}--> Error: Docker Hub authentication failed (HTTP $response).${NC}"
        return 1
    fi
}

# Function to validate the LB Range mathematically
validate_lb_range() {
    local range=$1
    
    # 1. Basic format check
    local range_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}-([0-9]{1,3}\.){3}[0-9]{1,3}$"
    if [[ ! $range =~ $range_regex ]]; then
        echo -e "${RED}--> Error: Invalid format! Use: x.x.x.x-y.y.y.y${NC}"
        return 1
    fi

    # 2. Split into start and end IPs
    local start_ip="${range%-*}"
    local end_ip="${range#*-}"

    # Helper function to convert an IP to a comparable integer
    ip_to_int() {
        local IFS=.
        read -r i1 i2 i3 i4 <<< "$1"
        
        # Ensure valid IP octets (0-255)
        if (( 10#$i1 > 255 || 10#$i2 > 255 || 10#$i3 > 255 || 10#$i4 > 255 )); then
            return 1
        fi
        
        # Convert to an integer using base-10 math
        echo $(( 10#$i1 * 16777216 + 10#$i2 * 65536 + 10#$i3 * 256 + 10#$i4 ))
    }

    local start_int end_int

    # 3. Convert and check for invalid octets (e.g. 999.999.999.999)
    if ! start_int=$(ip_to_int "$start_ip") || ! end_int=$(ip_to_int "$end_ip"); then
        echo -e "${RED}--> Error: Invalid IP address! Octets must be between 0 and 255.${NC}"
        return 1
    fi

    # 4. The actual mathematical comparison
    if (( start_int > end_int )); then
        echo -e "${RED}--> Error: Invalid range! Start IP ($start_ip) is higher than End IP ($end_ip).${NC}"
        return 1
    fi

    return 0
}

# Function to ensure LB IPs and VIP share the same /24 subnet
check_subnet_match() {
    local vip=$1
    local range=$2

    # Extract the first three octets
    local vip_network="${vip%.*}"
    local start_ip="${range%-*}"
    local end_ip="${range#*-}"
    local start_network="${start_ip%.*}"
    local end_network="${end_ip%.*}"

    if [[ "$vip_network" != "$start_network" || "$vip_network" != "$end_network" ]]; then
        echo -e "${RED}--> Error: Load Balancer IPs ($range) do not appear to be in the same /24 subnet as the VIP ($vip).${NC}"
        return 1
    fi
    return 0
}

check_dependencies

echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}      NKP Nutanix Cluster Deployment Initializer       ${NC}"
echo -e "${YELLOW}=======================================================${NC}"

# 1. Nutanix Connection Info
read -p "Prism Central Endpoint (IP only): " PC_ENDPOINT
read -p "Prism Username: " NUTANIX_USER
echo -n "Prism Password: "
read -s NUTANIX_PASSWORD
echo -e "\n"

# 2. Registry Mirror Logic
read -p "Is this being deployed in HPOC? (y/n): " IS_HPOC

if [[ "$IS_HPOC" =~ ^[Yy]$ ]]; then
    MIRROR_URL="https://registry.nutanixdemo.com/docker.io"
    MIRROR_USER=""
    MIRROR_PASS=""
    CLUSTER_NAME="nkp"
    echo -e "${GREEN}--> HPOC Mode Active. Using Nutanix Demo Registry (No Credentials) and nkp cluster name.${NC}"
else
    MIRROR_URL="https://registry-1.docker.io"
    while true; do
        read -p "Docker Mirror Username: " MIRROR_USER
        echo -n "Docker Mirror Password: "
        read -s MIRROR_PASS
        echo -e "\n"
        read -p "NKP Cluster Name: " CLUSTER_NAME
        
        if check_docker_creds "$MIRROR_USER" "$MIRROR_PASS"; then
            break
        else
            echo -e "${RED}Please re-enter your Docker credentials.${NC}"
        fi
    done
fi

# 3. Cluster Configuration
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
    if validate_lb_range "$LB_RANGE"; then
        if check_subnet_match "$VIP" "$LB_RANGE"; then
            break
        fi
    fi
done

# --- FINAL CONFIRMATION SCREEN ---
clear
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}           FINAL DEPLOYMENT SUMMARY                    ${NC}"
echo -e "${YELLOW}=======================================================${NC}"
printf "${CYAN}%-25s${NC} : %s\n" "Cluster Name" "$CLUSTER_NAME"
printf "${CYAN}%-25s${NC} : %s\n" "PC Endpoint" "$PC_ENDPOINT"
printf "${CYAN}%-25s${NC} : %s\n" "Nutanix User" "$NUTANIX_USER"
echo -e "-------------------------------------------------------"
printf "${CYAN}%-25s${NC} : %s\n" "Registry Mirror" "$MIRROR_URL"
if [ -n "$MIRROR_USER" ]; then
    printf "${CYAN}%-25s${NC} : %s\n" "Mirror Username" "$MIRROR_USER"
fi
echo -e "-------------------------------------------------------"
printf "${CYAN}%-25s${NC} : %s\n" "Control Plane VIP" "$VIP"
printf "${CYAN}%-25s${NC} : %s\n" "VM Image Name" "$VM_IMAGE"
printf "${CYAN}%-25s${NC} : %s\n" "AHV Cluster Name" "$AHV_CLUSTER"
printf "${CYAN}%-25s${NC} : %s\n" "AHV Network Name" "$NETWORK"
printf "${CYAN}%-25s${NC} : %s\n" "Storage Container Name" "$STORAGE"
printf "${CYAN}%-25s${NC} : %s\n" "Load Balancer Range" "$LB_RANGE"
echo -e "${YELLOW}=======================================================${NC}"

echo -e "${YELLOW}Proceed with deployment? (y/n)${NC}"
read -p "> " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled by user.${NC}"
    exit 0
fi

export NUTANIX_USER
export NUTANIX_PASSWORD
export NUTANIX_ENDPOINT="https://${PC_ENDPOINT}:9440"

echo -e "${GREEN}Starting NKP deployment...${NC}"

# Define extra flags for registry
REGISTRY_FLAGS=("--registry-mirror-url=$MIRROR_URL" "--skip-preflight-checks=Registry")
if [ -n "$MIRROR_USER" ]; then
    REGISTRY_FLAGS+=("--registry-mirror-username=$MIRROR_USER" "--registry-mirror-password=$MIRROR_PASS")
fi

# Run the deployment
nkp create cluster nutanix \
  "${REGISTRY_FLAGS[@]}" \
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
