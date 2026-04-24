# Nutanix Kubernetes Platform (NKP) Automated Deployment

![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash)
![Nutanix](https://img.shields.io/badge/Platform-Nutanix-0A2E66?style=flat-square)

An interactive, end-to-end Bash utility designed to streamline the provisioning of Nutanix Kubernetes Platform (NKP) clusters. This deployment script handles everything from configuring system-level prerequisites and managing bundle downloads, to validating Nutanix environment versions and executing the final cluster creation.

## 🌟 Key Features

- **Automated System Preparation:** Checks for and configures system-wide cgroup v2 delegation (requires `sudo`), prompting for a system reboot only if necessary.
- **Smart Bundle Management:** Detects existing local NKP release bundles. If missing, it prompts for a Nutanix portal download URL, then seamlessly fetches and extracts the contents on the fly.
- **Binary Auto-Installation:** Automatically extracts and installs essential binaries (`nkp` and `kubectl`) directly into `/usr/local/bin`.
- **API Version Validation:** Interfaces with the Prism Central API to ensure that both Prism Central and AOS versions are running version `> 7.3` before allowing deployment to proceed.
- **Interactive & Secure:** Provides a color-coded CLI experience, safely masks password inputs, and displays a pre-flight summary table that requires manual user confirmation prior to touching your infrastructure.
- **Cloud-Init Integration:** Includes a base `cloud-init` configuration file for easily bootstrapping the bastion host used in your deployment.

## 🛠️ Prerequisites

Unlike older deployment methods, you **do not** need to have `nkp` or `kubectl` pre-installed on your machine—this script provisions them for you! However, the deployment host must have the following available:

- `curl` (for fetching bundles and making API requests)
- `jq` (required to parse Nutanix JSON API responses)
- `tar` (for archive extraction)
- `sudo` privileges (for cgroup delegation and installing binaries to system paths)

## 🚀 Getting Started

### 1. Clone the Repository
Clone the repository to the machine you intend to run the deployment from:
```bash
git clone [https://github.com/mbaran5/nkpdeploy.git](https://github.com/mbaran5/nkpdeploy.git)
cd nkpdeploy
```

### 2. Make the Script Executable
Give the primary script the necessary execution permissions:
```bash
chmod +x nkpDeploy.sh
```

### 3. Run the Deployment Script
Launch the interactive CLI tool:
```bash
./nkpDeploy.sh
```

### 4. Follow the Interactive Prompts
The script will safely guide you through entering your:
- Prism Central IP/FQDN and credentials
- Target cluster names and compute specifications
- Networking information

Review and confirm the details in the final pre-flight summary table to kick off the cluster build.

## ⚙️ Environment Variables

For convenience and seamless execution, the script automatically sets and exports the following environment variables required by the `nkp` binary during runtime:

- `NUTANIX_USER`: Your Prism Central username.
- `NUTANIX_PASSWORD`: Your Prism Central password.
- `NUTANIX_ENDPOINT`: The Prism Central API endpoint.
- `KUBECONFIG`: Sets the context to the newly created cluster's config file (generated in your current working directory).
