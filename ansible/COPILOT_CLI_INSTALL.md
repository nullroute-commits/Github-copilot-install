# GitHub Copilot CLI Installation for Proxmox 9

This directory contains Ansible playbooks and configurations for installing the latest stable release of GitHub Copilot CLI on Proxmox 9 nodes.

## Overview

GitHub Copilot CLI brings AI-powered assistance directly to your command line. This installation automates the deployment on Proxmox 9 nodes (based on Debian 13).

### Latest Stable Version

**Current Release:** v0.0.359 (as of November 2025)

## Prerequisites

Before running the installation playbook, ensure:

1. **Target System**: Proxmox 9 node(s) with SSH access
2. **Ansible**: Version 10.5.0+ installed on the control machine
3. **GitHub Copilot Subscription**: Active subscription (Pro, Pro+, Business, or Enterprise)
4. **Network Access**: Target nodes must have internet connectivity to download packages

### System Requirements (Per Node)

- **OS**: Proxmox VE 9 (Debian 13 "Trixie" based)
- **Disk Space**: ~500MB for Node.js, npm, and GitHub Copilot CLI
- **Memory**: Minimum 1GB available RAM
- **Network**: Internet access for package downloads

## Installation

### Quick Start

1. **Configure Inventory**

   Edit the inventory file to match your Proxmox node(s):
   ```bash
   nano ansible/inventories/proxmox/hosts.yml
   ```

   Update the host IP addresses and connection details:
   ```yaml
   proxmox-node-01:
     ansible_host: 192.168.1.100  # Change to your node's IP
     ansible_user: root
   ```

2. **Run the Installation Playbook**

   ```bash
   # From the repository root
   ansible-playbook -i ansible/inventories/proxmox/hosts.yml \
     ansible/playbooks/install-github-copilot-cli.yml
   ```

3. **Verify Installation**

   SSH into your Proxmox node and run:
   ```bash
   verify-copilot-install
   ```

   Or manually check:
   ```bash
   copilot --version
   node --version
   npm --version
   ```

### Detailed Installation Steps

#### Step 1: Prepare the Ansible Control Node

Ensure Ansible is installed:
```bash
# Check Ansible version
ansible --version

# If not installed, install on Debian/Ubuntu:
apt update
apt install ansible

# Or use pip:
pip3 install ansible
```

#### Step 2: Configure SSH Access

Ensure you can SSH into your Proxmox nodes:
```bash
# Test SSH connection
ssh root@192.168.1.100

# Set up SSH keys if needed (recommended)
ssh-copy-id root@192.168.1.100
```

#### Step 3: Customize Variables (Optional)

The playbook uses sensible defaults, but you can customize:

```yaml
# In ansible/inventories/proxmox/hosts.yml
vars:
  nodejs_version: "22"        # Node.js major version
  npm_version: "10"           # npm major version
  copilot_cli_package: "@github/copilot"
```

#### Step 4: Execute Playbook

```bash
# Run with default settings
ansible-playbook -i ansible/inventories/proxmox/hosts.yml \
  ansible/playbooks/install-github-copilot-cli.yml

# Run with verbose output for troubleshooting
ansible-playbook -i ansible/inventories/proxmox/hosts.yml \
  ansible/playbooks/install-github-copilot-cli.yml -vv

# Run with a specific user (if not using root)
ansible-playbook -i ansible/inventories/proxmox/hosts.yml \
  ansible/playbooks/install-github-copilot-cli.yml \
  --user=admin --become
```

#### Step 5: Verify Installation

On each Proxmox node, run:
```bash
# Use the verification script
verify-copilot-install

# Or check manually
copilot --version
which copilot
```

## What Gets Installed

The playbook installs the following components in order:

1. **System Packages**:
   - curl, wget, ca-certificates
   - gnupg, build-essential

2. **Node.js 22.x**: Latest LTS version from NodeSource repository
3. **npm 10.x**: Package manager, upgraded to version 10+
4. **GitHub Copilot CLI**: Latest stable release (@github/copilot)

### Installation Paths

- **Node.js**: `/usr/bin/node`
- **npm**: `/usr/bin/npm`
- **Copilot CLI**: `/usr/bin/copilot` (global npm installation)
- **Verification Script**: `/usr/local/bin/verify-copilot-install`

## Usage

### First-Time Setup

After installation, authenticate with GitHub:

```bash
# Launch Copilot CLI
copilot

# In the Copilot CLI, authenticate
/login
```

Follow the browser-based authentication flow to link your GitHub account.

### Basic Commands

```bash
# Start Copilot CLI interactive session
copilot

# Get help
/help

# Ask a question
How do I create a systemd service?

# Generate a command
Generate a command to list all running Docker containers

# Explain code
Explain this bash script: <paste your script>
```

### Slash Commands

Within the Copilot CLI:
- `/help` - Show available commands
- `/login` - Authenticate with GitHub
- `/logout` - Sign out
- `/clear` - Clear conversation history
- `/exit` - Exit Copilot CLI

## Troubleshooting

### Common Issues

#### 1. Copilot CLI Not Found

**Symptom**: `copilot: command not found`

**Solution**:
```bash
# Check if npm global bin is in PATH
echo $PATH | grep npm

# Add npm global bin to PATH
export PATH=$PATH:/usr/lib/node_modules/.bin

# Or reinstall globally
npm install -g @github/copilot
```

#### 2. Authentication Fails

**Symptom**: Cannot authenticate with GitHub

**Solution**:
- Verify you have an active GitHub Copilot subscription
- Check if your organization allows Copilot CLI usage
- Try logging out and back in: `/logout` then `/login`

#### 3. Node.js Version Issues

**Symptom**: Node.js version is too old

**Solution**:
```bash
# Check current version
node --version

# Reinstall Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
```

#### 4. npm Permission Errors

**Symptom**: Permission denied when installing packages

**Solution**:
```bash
# Fix npm permissions
npm config set prefix /usr/local

# Or use sudo
sudo npm install -g @github/copilot
```

### Logs and Diagnostics

```bash
# Check Ansible playbook execution logs
ansible-playbook -i ansible/inventories/proxmox/hosts.yml \
  ansible/playbooks/install-github-copilot-cli.yml -vvv

# Check npm installation logs
npm list -g --depth=0

# Check Node.js and npm versions
node --version
npm --version
```

## Updating

To update GitHub Copilot CLI to the latest version:

```bash
# On the Proxmox node
npm update -g @github/copilot

# Or reinstall
npm uninstall -g @github/copilot
npm install -g @github/copilot
```

## Uninstallation

To remove GitHub Copilot CLI:

```bash
# Remove Copilot CLI
npm uninstall -g @github/copilot

# Optional: Remove Node.js and npm
apt remove nodejs
apt autoremove
```

## Multiple Nodes

To install on multiple Proxmox nodes simultaneously:

1. Add all nodes to `ansible/inventories/proxmox/hosts.yml`:
   ```yaml
   proxmox_nodes:
     hosts:
       proxmox-node-01:
         ansible_host: 192.168.1.100
       proxmox-node-02:
         ansible_host: 192.168.1.101
       proxmox-node-03:
         ansible_host: 192.168.1.102
   ```

2. Run the playbook once - it will install on all nodes in parallel

## Security Considerations

- The playbook runs with elevated privileges (become: yes)
- SSH keys are recommended over password authentication
- Keep Node.js and npm updated for security patches
- GitHub Copilot CLI communicates with GitHub's servers - ensure your security policies allow this

## Support

### Documentation

- **GitHub Copilot CLI**: https://docs.github.com/copilot/how-tos/set-up/install-copilot-cli
- **Proxmox VE 9**: https://pve.proxmox.com/pve-docs-9-beta/
- **Ansible**: https://docs.ansible.com/

### Issues

If you encounter issues:
1. Check the troubleshooting section above
2. Verify your GitHub Copilot subscription is active
3. Ensure your Proxmox node has internet connectivity
4. Review Ansible playbook output for error messages

## License

This project follows the repository's main license. GitHub Copilot CLI usage is subject to GitHub's terms of service.

## Changelog

### Version 1.0.0 (November 2025)
- Initial release
- Support for Proxmox VE 9 (Debian 13 based)
- Installs Node.js 22.x
- Installs npm 10.x
- Installs GitHub Copilot CLI v0.0.359 (latest stable)
- Includes verification script
- Multi-node support via Ansible

---

**Note**: This installation is specifically designed for Proxmox 9 nodes. For other operating systems or Proxmox versions, modifications may be required.
