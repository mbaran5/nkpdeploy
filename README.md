# Nutanix NKP Deployment Script

An interactive Bash utility to streamline the deployment of Nutanix Kubernetes Platform (NKP) clusters. This script eliminates manual export errors by validating inputs like Docker Hub credentials and IP ranges before execution.

## 🚀 Features

* **Validation**: Checks for `.qcow2` extensions and valid IPv4 range formats.
* **Security**: Masked password inputs and pre-flight Docker Hub authentication checks.
* **Dependency Check**: Verifies `nkp`, `kubectl`, and `curl` are installed before starting.
* **Color-Coded UI**: Includes a final confirmation summary to prevent deployment mistakes.

## 🛠 Prerequisites

Ensure the following are installed and in your `$PATH`:

* `nkp` (Nutanix Kubernetes Platform CLI)
* `kubectl`
* `curl`

## 📖 How to Use

1. **Clone or Copy** the script to your environment.
2. **Make it executable**:
```bash
chmod +x deploy_nkp.sh

```


3. **Run the script**:
```bash
./deploy_nkp.sh

```



## 📝 Environment Variables Used

The script automatically exports the following for the `nkp` binary:

* `NUTANIX_USER`
* `NUTANIX_PASSWORD`
* `NUTANIX_ENDPOINT`
