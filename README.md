# Polkit Lab

An isolated environment to test and verify Polkit (PolicyKit) configurations using lightweight systemd containers (`systemd-nspawn`).

## Setup & Initialization

### 1. Automatic Setup (Recommended)

Run the automated setup script to detect your host OS, install necessary dependencies (`systemd-container`, `polkit`, etc.), bootstrap a minimal root filesystem, and configure the default users:

> Arch Linux; Ubuntu/Debian; Fedora
```bash
sudo ./setup.sh
```

This creates the container environment inside the `env/` directory and sets up the following defaults:
- **Root password**: `root`
- **Operator user**: `operator` (password: `123`, member of `agora-operators` group)

---

## Running the Automated Test

You can sync the latest configurations to the sandbox and run the automated test suite directly:

```bash
sudo ./test.sh
```

This script will:
1. Sync files (`agora-service.sh`, `agora.service`, and the Polkit rules) into the sandbox container.
2. Boot the container in the background.
3. Reload systemd daemons and Polkit inside the container.
4. Execute a restart command as the `operator` user to verify if the Polkit policy permits it without a password.
5. Clean up and shut down the container.

---

## Manual Verification

If you want to manually log in and test behaviors inside the sandbox container:

### 1. Boot the Container
```bash
sudo systemd-nspawn --machine=polkit-lab --boot --directory=env
```
*(Login as `root` with password `root`, or as `operator` with password `123`)*

### 2. Run Commands as Operator
In another terminal, you can run commands inside the container as the `operator` user:
```bash
sudo systemd-run -M polkit-lab -P -q --collect --uid=operator /usr/bin/systemctl restart agora.service
```

### 3. Test Scenarios
- **Scenario 1: Should Allow (No Password)**
  ```bash
  systemctl restart agora.service
  ```
- **Scenario 2: Should Deny (Requires Root/Password)**
  ```bash
  systemctl stop polkit.service
  ```

---

## Repository Structure

```text
.
├── configs/
│   ├── 10-agora-manager.rules   # Polkit policy rules definition
│   └── agora.service            # Systemd service unit descriptor
├── scripts/
│   └── agora-service.sh         # Target mock script executed by the service
├── README.md
├── setup.sh                     # Cross-distro host dependencies & rootfs bootstrap
└── test.sh                      # Automated testing orchestrator
```

