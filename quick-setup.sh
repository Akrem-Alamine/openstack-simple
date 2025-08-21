#!/bin/bash

# Quick Setup Script for GCP VM Host
# This script prepares the environment and guides through the deployment

set -e

echo "========================================="
echo "OpenStack Quick Setup for GCP VM Host"
echo "========================================="

# Function to print colored output
print_step() {
    echo -e "\n\033[1;34m==== $1 ====\033[0m"
}

print_success() {
    echo -e "\033[1;32m✓ $1\033[0m"
}

print_error() {
    echo -e "\033[1;31m✗ $1\033[0m"
}

print_warning() {
    echo -e "\033[1;33m⚠ $1\033[0m"
}

# Step 1: Check if running on correct system
print_step "Checking System Requirements"

if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Check if we're on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    print_warning "This script is designed for Ubuntu. Proceed with caution."
fi

print_success "System check passed"

# Step 2: Install prerequisites
print_step "Installing Prerequisites"

sudo apt update
sudo apt install -y ansible git python3-pip curl wget

print_success "Prerequisites installed"

# Step 3: Check for existing directory
if [ -d "openstack-simple" ]; then
    print_warning "Directory 'openstack-simple' already exists"
    read -p "Do you want to remove it and start fresh? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf openstack-simple
        print_success "Removed existing directory"
    else
        print_error "Please remove or rename the existing directory"
        exit 1
    fi
fi

# Step 4: Get the files (you'll need to modify this based on how you transfer files)
print_step "Setting up OpenStack files"

echo "Please transfer your OpenStack files to this directory."
echo "You can:"
echo "1. Use git clone if you've pushed to a repository"
echo "2. Use scp to copy from your Windows machine"
echo "3. Create the directory structure manually"
echo ""
read -p "Press Enter after you've placed the files in 'openstack-simple' directory..."

if [ ! -d "openstack-simple" ]; then
    print_error "Directory 'openstack-simple' not found!"
    echo "Please create the directory and copy your files."
    exit 1
fi

cd openstack-simple

# Step 5: Make scripts executable
print_step "Setting up permissions"
chmod +x scripts/*.sh
print_success "Scripts made executable"

# Step 6: Detect VMs
print_step "Detecting Virtual Machines"

echo "Checking for running VMs..."

# Try different virtualization platforms
if command -v virsh &> /dev/null; then
    echo "Found libvirt/KVM:"
    virsh list --all
    VM_PLATFORM="libvirt"
elif command -v VBoxManage &> /dev/null; then
    echo "Found VirtualBox:"
    VBoxManage list vms
    VM_PLATFORM="virtualbox"
elif command -v docker &> /dev/null; then
    echo "Found Docker containers:"
    docker ps -a
    VM_PLATFORM="docker"
else
    print_warning "No common virtualization platform detected"
    echo "Please manually identify your VM IPs"
    VM_PLATFORM="manual"
fi

# Step 7: Network discovery
print_step "Network Discovery"

echo "Host network interfaces:"
ip addr show | grep "inet " | grep -v "127.0.0.1"

echo ""
echo "Looking for VM networks..."
if [ "$VM_PLATFORM" == "libvirt" ]; then
    echo "Libvirt networks:"
    virsh net-list
    echo ""
    echo "Bridge interfaces:"
    brctl show 2>/dev/null || echo "Bridge utils not installed"
fi

# Step 8: SSH Key setup
print_step "SSH Key Setup"

SSH_KEY="$HOME/.ssh/openstack_key"

if [ ! -f "$SSH_KEY" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N ""
    print_success "SSH key generated: $SSH_KEY"
else
    print_warning "SSH key already exists: $SSH_KEY"
fi

# Step 9: Configuration guidance
print_step "Configuration Setup"

echo "Please configure the following files:"
echo ""
echo "1. Edit inventory/hosts:"
echo "   nano inventory/hosts"
echo "   Update with your VM IP addresses"
echo ""
echo "2. Edit group_vars/all.yml:"
echo "   nano group_vars/all.yml"
echo "   Update controller_ip, storage_ip, compute_ip"
echo ""
echo "Example VM IPs to look for:"
echo "- 192.168.122.x (libvirt default)"
echo "- 192.168.56.x (VirtualBox)"
echo "- 172.17.0.x (Docker)"
echo ""

read -p "Press Enter after you've updated the configuration files..."

# Step 10: Test connectivity
print_step "Testing VM Connectivity"

echo "Testing SSH connectivity to VMs..."
if ansible all -i inventory/hosts -m ping --private-key "$SSH_KEY"; then
    print_success "All VMs are reachable!"
else
    print_error "Some VMs are not reachable"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check VM IPs in inventory/hosts"
    echo "2. Ensure VMs are running"
    echo "3. Copy SSH keys to VMs:"
    echo "   ssh-copy-id -i $SSH_KEY ubuntu@VM_IP"
    echo ""
    read -p "Fix the issues and press Enter to continue..."
fi

# Step 11: Final deployment prompt
print_step "Ready for Deployment"

echo "System is ready for OpenStack deployment!"
echo ""
echo "To deploy OpenStack, run:"
echo "  ./scripts/deploy.sh"
echo ""
echo "Or run step by step:"
echo "  ansible-playbook -i inventory/hosts playbooks/site.yml --private-key $SSH_KEY"
echo ""
echo "Monitor progress in another terminal:"
echo "  tail -f /var/log/ansible.log"
echo ""

read -p "Do you want to start the deployment now? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_step "Starting OpenStack Deployment"
    ansible-playbook -i inventory/hosts playbooks/site.yml --private-key "$SSH_KEY"
    
    if [ $? -eq 0 ]; then
        print_success "Deployment completed successfully!"
        echo ""
        echo "Access your OpenStack dashboard:"
        CONTROLLER_IP=$(grep controller inventory/hosts | cut -d'=' -f2 | tr -d ' ')
        echo "URL: http://$CONTROLLER_IP/horizon"
        echo "Username: admin"
        echo "Password: openstack123"
        echo ""
        echo "Run validation: ./scripts/validate.sh"
    else
        print_error "Deployment failed! Check the logs above."
    fi
else
    echo "Deployment skipped. Run './scripts/deploy.sh' when ready."
fi

echo ""
print_success "Setup script completed!"
