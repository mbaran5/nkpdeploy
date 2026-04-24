# Nutanix Enterprise AI (NAI) Deployment Walkthrough

![Kubernetes](https://img.shields.io/badge/Platform-Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![Nutanix](https://img.shields.io/badge/Platform-Nutanix_Enterprise_AI-0A2E66?style=flat-square)
![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash)

This document provides a technical walkthrough for deploying **Nutanix Enterprise AI (NAI)** on top of the Nutanix Kubernetes Platform (NKP). It covers hardware sizing, prerequisite applications, and the baseline cluster configurations required before initiating the deployment via the NKP App Catalog.

---

## 📋 Prerequisites

Before beginning the deployment, ensure your environment meets the following hardware, storage, and software requirements:

### 1. Hardware Requirements
* **vCPU:** Worker nodes must have a minimum of **24 vCPU** to run the Gemma 2b model.
* **CPU Architecture:** **AVX-512** instruction set support is strictly required to run any Llama 3.2 model (Intel Sapphire Rapids or newer).

### 2. Storage Requirements
* **Nutanix Files:** Must be deployed with an NFS share present, active, and reachable by the worker nodes.

### 3. Required NKP Applications
Ensure the following applications are marked as **"Enabled"** within your target NKP cluster/workspace:
* `cert-manager`
* `envoy-gateway`
* `prometheus` (Prometheus Monitoring)
* `nvidia-gpu-operator`
* `kserve`
* `opentelemetry-operator`

### 4. Authentication
* **Docker Credentials:** You must have access to the Nutanix Support Portal to retrieve your NAI Docker credentials/PAT (Personal Access Token). These are found under *Downloads > Nutanix Enterprise AI*.

---

## ⚙️ Pre-Deployment Configuration

Before installing NAI from the application catalog, the cluster needs specific namespaces, storage classes, and registry secrets. 

Use the provided bash script to interactively deploy the prerequisites.

```bash
# Download helper script and make it executable
curl -L https://raw.githubusercontent.com/mbaran5/nkpdeploy/refs/heads/main/nai/preDeploy.sh -o naiDeploy.sh
chmod +x naiDeploy.sh

# Execute the script and fill in the prompts
./naiDeploy.sh
```

## 🚀 Installation

Once the prerequisite configurations (StorageClass, Namespaces, and Secrets) are successfully applied to your cluster, proceed with the UI installation.

1. Log into your **NKP Dashboard**.
2. Navigate to the **NKP Application Catalog**.
3. Locate and select the **Nutanix Enterprise AI** application.
4. During the configuration phase, you **must** specify the following YAML override to ensure the pods can pull the proprietary images:

```yaml
global:
  imagePullSecrets:
    - name: nai-regcred
```

5. Deploy the application and monitor the pods in the `nai-system` namespace until they reach a `Running` state.
