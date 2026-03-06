#!/bin/bash

# Function to check for required binaries
check_dependencies() {
    local dependencies=("nkp" "kubectl" "curl")
    local missing_deps=0
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Error: Required binary '$dep' is not installed or not in PATH."
            missing_deps=1
        fi
    done
    [[ $missing_deps -ne 0 ]] && exit 1
}

# Function to validate Docker Hub / Mirror credentials
check_docker_creds() {
    local user=$1
    local pass=$2
    echo "Verifying Registry credentials..."
    
    # Attempt to get an auth token from Docker Hub
    local response=$(curl -s -o /dev/null -w "%{http_code}" -u "$user:$pass" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview:pull")

    if [ "$response" == "200" ]; then
        echo "--> Registry authentication successful!"
        return 0
    else
        echo "--> Error: Registry authentication failed (HTTP $response). Check your username/password."
        return 1
    fi
}

# Function to validate LB Range format
validate_lb_range() {
    local range_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}-([0-9]{1,3}\.){3}[0-9]{1,3}$"
    [[ $1 =~ $range_regex ]]
}

check_dependencies

echo "-------------------------------------------------------"
echo "  NKP Nutanix Cluster Deployment Initializer"
echo "-------------------------------------------------------"

# 1. Nutanix Connection Info
while true; do
    read -p "Prism Central Endpoint (IP): " PC_ENDPOINT
    if ping -c 1 -W 2 "$PC_ENDPOINT" &> /dev/null; then
        echo "--> Endpoint reachable."
        break
    else
        echo "--> Error: Cannot ping $PC_ENDPOINT. Check the IP or your VPN."
    fi
done

read -p "Nutanix Username: " NUTANIX_USER
echo -n "Nutanix Password: "
read -s NUTANIX_PASSWORD
echo -e "\n"

# 2. Registry Mirror Info with Validation Loop
while true; do
    read -p "Docker Mirror Username: " MIRROR_USER
    echo -n "Docker Mirror Password: "
    read -s MIRROR_PASS
    echo -e "\n"
    
    if check_docker_creds "$MIRROR_USER" "$MIRROR_PASS"; then
        break
    else
        echo "Please re-enter your Docker credentials."
    fi
done

# 3. Cluster Configuration
read -p "NKP Cluster Name: " CLUSTER_NAME
read -p "Control Plane VIP: " VIP

# VM Image Validation
while true; do
    read -p "VM Image Name (must include .qcow2): " VM_IMAGE
    if [[ "$VM_IMAGE" == *.qcow2 ]]; then
        break
    else
        echo "--> Error: Filename must end with '.qcow2'."
    fi
done

read -p "AHV Cluster (Prism Element): " AHV_CLUSTER
read -p "Network Name: " NETWORK
read -p "Storage Container: " STORAGE

# LB Range Validation
while true; do
    read -p "Load Balancer IP Range (x.x.x.x-x.x.x.x): " LB_RANGE
    if validate_lb_range "$LB_RANGE"; then
        break
    else
        echo "--> Invalid format! Use: 10.38.239.11-10.38.239.20"
    fi
done

# Export Nutanix credentials
export NUTANIX_PASSWORD

echo "-------------------------------------------------------"
echo "SUMMARY OF CONFIGURATION:"
echo "Cluster Name:    $CLUSTER_NAME"
echo "Endpoint:        $PC_ENDPOINT"
echo "Registry Mirror: https://registry-1.docker.io"
echo "Preflights:      Skipping Registry check (--skip-preflight-checks=Registry)"
echo "-------------------------------------------------------"
read -p "Press [Enter] to start deployment or Ctrl+C to exit..."

# Run the deployment
nkp create cluster nutanix \
  --cluster-name "${CLUSTER_NAME}" \
  --registry-mirror-url "https://registry-1.docker.io" \
  --registry-mirror-username "${MIRROR_USER}" \
  --registry-mirror-password "${MIRROR_PASS}" \
  --skip-preflight-checks=Registry \
  --endpoint "https://${PC_ENDPOINT}:9440" \
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
