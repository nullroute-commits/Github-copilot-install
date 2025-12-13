# GitHub Copilot CLI - Quick Reference

## Installation (One-Time Setup)

### Step 1: Configure
```bash
nano ansible/inventories/proxmox/hosts.yml
```
Update the `ansible_host` with your Proxmox node's IP address.

### Step 2: Install
```bash
./install-copilot-cli.sh
```
Or manually:
```bash
ansible-playbook -i ansible/inventories/proxmox/hosts.yml \
  ansible/playbooks/install-github-copilot-cli.yml
```

## Usage (SSH to Proxmox Node)

### Verify Installation
```bash
verify-copilot-install
copilot --version
```

### First-Time Authentication
```bash
copilot      # Launch Copilot CLI
/login       # Follow authentication prompts
```

### Basic Commands
```bash
# Start Copilot
copilot

# Inside Copilot CLI
/help        # Show all commands
/login       # Authenticate with GitHub
/logout      # Sign out
/clear       # Clear conversation
/exit        # Exit Copilot CLI
```

## Common Use Cases

### Ask Questions
```
How do I create a systemd service?
Explain what iptables does
What's the difference between apt and apt-get?
```

### Generate Commands
```
Generate a command to find all files larger than 100MB
Create a bash script to backup /var/log
Show me how to configure nginx as reverse proxy
```

### Code Help
```
Explain this bash script: [paste script]
Debug this error: [paste error]
Optimize this command: [paste command]
```

## Troubleshooting

### Copilot Not Found
```bash
which copilot           # Check if installed
npm list -g @github/copilot  # Check npm installation
export PATH=$PATH:/usr/lib/node_modules/.bin  # Add to PATH
```

### Authentication Issues
1. Ensure you have active GitHub Copilot subscription
2. Check organizational policies allow Copilot CLI
3. Try: `/logout` then `/login` again

### Update Copilot
```bash
npm update -g @github/copilot
copilot --version  # Verify new version
```

## System Requirements

- **OS**: Proxmox VE 9 (Debian 13 based)
- **Disk**: ~500MB free space
- **RAM**: 1GB+ available
- **Network**: Internet access
- **Subscription**: GitHub Copilot Pro/Business/Enterprise

## Version Information

- **Node.js**: 22.x (LTS)
- **npm**: 10.x or higher
- **Copilot CLI**: latest stable

## Quick Links

- 📖 Full Documentation: `ansible/COPILOT_CLI_INSTALL.md`
- 🔧 Implementation: `IMPLEMENTATION_SUMMARY.md`
- 🐙 GitHub Docs: https://docs.github.com/copilot/how-tos/set-up/install-copilot-cli

## Need Help?

1. Check troubleshooting in `ansible/COPILOT_CLI_INSTALL.md`
2. Run installation with verbose: `./install-copilot-cli.sh --verbose`
3. Test SSH: `ansible -i ansible/inventories/proxmox/hosts.yml all -m ping`
4. Verify prerequisites: Ansible installed, SSH access configured

---

**Pro Tip**: Use Copilot CLI for system administration tasks, debugging, learning new commands, and getting instant help without leaving the terminal!
