# NAI Prerequisites Deployment Script

![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash)
![Kubernetes](https://img.shields.io/badge/Platform-Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![Nutanix](https://img.shields.io/badge/Storage-Nutanix_CSI-0A2E66?style=flat-square)

An interactive Bash script designed to bootstrap a Kubernetes cluster with the necessary foundational components required to deploy NAI (Nutanix AI) via the NKP Application Catalog. 

## 🌟 Overview

Before deploying NAI, the target Kubernetes cluster needs specific storage classes, namespaces, and registry access configurations. This script automates that groundwork to prevent deployment failures. It provides a color-coded, interactive CLI that safely accepts your credentials and configuration details, presents a pre-flight summary for review, and applies the necessary Kubernetes manifests.

## ⚙️ What It Does

When executed, the script performs the following actions on your target cluster:
1. **Configures Storage:** Generates and applies a Nutanix Files NFS `StorageClass` (`nai-nfs-storage`) utilizing the `csi.nutanix.com` provisioner.
2. **Creates Namespaces:** Sets up the `nai-system` and `envoy-gateway-system` namespaces.
3. **Applies Registry Secrets:** Generates Docker registry pull secrets (`nai-regcred`) in both of the newly created namespaces using your DockerHub credentials, ensuring the cluster can authenticate and pull required images.

## 🛠️ Prerequisites

To run this script successfully, you will need the following ready:
* **`kubectl`** installed on the machine running the script.
* A valid **Kubeconfig file** for the target Kubernetes cluster.
* An accessible **NFS Server** (and its path) to be used for the Nutanix Files StorageClass.
* An **NAI DockerHub Username** and **NAI Personal Access Token (PAT)**.

## 🚀 Usage

### 1. Make the script executable
If you haven't already, grant the script execution permissions:
```bash
chmod +x preDeploy.sh
```

### 2. Run the script
Execute the script from your terminal:
```bash
./preDeploy.sh
```

### 3. Provide the requested inputs
The script will prompt you for the following information:
* **Kubeconfig File Path:** The absolute or relative path to your cluster's kubeconfig.
* **NFS Path:** The export path on your NFS server (e.g., `/export/nai`).
* **NFS Server:** The IP address or hostname of your NFS server.
* **DockerHub Username:** Your DockerHub login.
* **DockerHub PAT:** Your secure Personal Access Token (input will be hidden).

### 4. Confirm the Deployment
A final deployment summary table will be displayed. Review the details carefully. If everything looks correct, type `y` to proceed and apply the configurations to the cluster.

---

## 🔗 Next Steps

Once the script completes successfully and outputs `Prerequisites completed successfully!`, the cluster is primed. You can now transition to the **NKP Application Store** UI to finish the application installation by specifying the following override during deployment
```
global:
  imagePullSecrets:
    - name: nai-regcred
```
