# Nutanix NKP Automated Deployment Script

An interactive Bash utility designed to streamline the provisioning of Nutanix Kubernetes Platform (NKP) clusters. This script handles the end-to-end setup: from configuring system-level prerequisites and downloading the NKP bundle, to validating Nutanix environment versions and executing the final deployment.

## 🚀 Features

* **Automated System Prep**: Automatically checks for and configures system-wide cgroup v2 delegation (requires `sudo`), prompting for a reboot if necessary.
* **Bundle Management**: Automatically detects local NKP release bundles or prompts for a Nutanix portal download URL to fetch and extract it on the fly.
* **Auto-Install Binaries**: Extracts and installs the required `nkp` and `kubectl` binaries directly to `/usr/local/bin`.
* **API Version Validation**: Connects to your Prism Central instance to verify that both Prism Central and AOS versions are > 7.3 before allowing deployment.
* **Interactive & Safe**: Features a color-coded CLI, masked password inputs, and a final pre-flight summary table requiring manual confirmation before any infrastructure is deployed.

## 🛠 Prerequisites

Unlike previous versions, you do **not** need `nkp` or `kubectl` pre-installed. The script will handle that for you. However, the machine running the script must have:

* `curl` (for downloading bundles and API calls)
* `jq` (essential for parsing Nutanix JSON API responses)
* `tar` (for bundle extraction)
* `sudo` privileges (for cgroup delegation and binary installation)

## 📖 How to Use

1. **Clone or Copy** the script to your deployment environment.
2. **Make it executable**:
   ```bash
   chmod +x deploy_nkp.sh
   ```

3. **Run the script**:
   ```bash
   ./deploy_nkp.sh
   ```

4. **Follow the prompts**: The script will guide you through entering your Prism credentials, cluster details, and networking information.

## 📝 Environment Variables Set

During execution, the script automatically exports the following variables required by the `nkp` binary:

* `NUTANIX_USER`
* `NUTANIX_PASSWORD`
* `NUTANIX_ENDPOINT`
* `KUBECONFIG` (Sets the path to the newly created cluster's config file in your current working directory)
