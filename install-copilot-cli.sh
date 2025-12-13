#!/bin/bash
# GitHub Copilot CLI Installation Script for Proxmox 9
# This script provides a quick way to install GitHub Copilot CLI on Proxmox nodes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running from repository root
if [ ! -f "ansible/playbooks/install-github-copilot-cli.yml" ]; then
    print_error "This script must be run from the repository root directory"
    exit 1
fi

# Display banner
echo "=========================================="
echo "  GitHub Copilot CLI Installation"
echo "  Target: Proxmox 9 Nodes"
echo "=========================================="
echo ""

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v ansible-playbook &> /dev/null; then
    print_error "Ansible is not installed. Please install Ansible 10.5.0+ first."
    echo "Installation instructions:"
    echo "  Ubuntu/Debian: sudo apt install ansible"
    echo "  Or via pip: pip3 install ansible"
    exit 1
fi

print_info "Ansible found: $(ansible-playbook --version | head -n1)"

# Check if inventory file exists
INVENTORY_FILE="ansible/inventories/proxmox/hosts.yml"
if [ ! -f "$INVENTORY_FILE" ]; then
    print_error "Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

# Display inventory information
print_info "Reading inventory file..."
echo ""
print_warn "Please ensure your Proxmox node(s) are configured in:"
print_warn "  $INVENTORY_FILE"
echo ""

# Prompt for confirmation
read -p "Have you configured your Proxmox node details in the inventory file? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warn "Please edit $INVENTORY_FILE with your node details first."
    echo ""
    echo "Example configuration:"
    echo "  proxmox-node-01:"
    echo "    ansible_host: 192.168.1.100"
    echo "    ansible_user: root"
    exit 0
fi

# Check SSH connectivity (optional)
print_info "Testing SSH connectivity to nodes..."
if ansible -i "$INVENTORY_FILE" all -m ping &> /dev/null; then
    print_info "Successfully connected to all nodes"
else
    print_warn "Could not connect to some nodes. Proceeding anyway..."
    print_warn "Ensure SSH keys are set up or you'll be prompted for passwords."
fi

echo ""
print_info "Starting installation..."
echo ""

# Run the playbook
PLAYBOOK="ansible/playbooks/install-github-copilot-cli.yml"

# Check for verbose flag
VERBOSE=""
if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
    VERBOSE="-vv"
    print_info "Running in verbose mode"
fi

if ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK" "$VERBOSE"; then
    echo ""
    echo "=========================================="
    print_info "Installation completed successfully!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. SSH into your Proxmox node"
    echo "  2. Run: verify-copilot-install"
    echo "  3. Launch Copilot: copilot"
    echo "  4. Authenticate: /login"
    echo ""
    echo "For detailed documentation, see:"
    echo "  ansible/COPILOT_CLI_INSTALL.md"
    echo ""
else
    echo ""
    print_error "Installation failed. Please check the error messages above."
    echo ""
    echo "Troubleshooting tips:"
    echo "  1. Verify SSH connectivity: ansible -i $INVENTORY_FILE all -m ping"
    echo "  2. Check inventory file: $INVENTORY_FILE"
    echo "  3. Run with verbose mode: $0 --verbose"
    echo "  4. See documentation: ansible/COPILOT_CLI_INSTALL.md"
    echo ""
    exit 1
fi
