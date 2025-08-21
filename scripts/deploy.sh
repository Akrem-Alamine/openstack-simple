#!/bin/bash

# Simple OpenStack Deployment Script
# This script deploys a minimal OpenStack environment

set -e

echo "========================================"
echo "Simple OpenStack Deployment Starting..."
echo "========================================"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "Installing Ansible..."
    sudo apt update
    sudo apt install -y ansible
fi

# Validate inventory
echo "Validating inventory..."
if ! ansible all -i inventory/hosts -m ping; then
    echo "ERROR: Cannot reach all hosts. Please check your inventory file and SSH connectivity."
    exit 1
fi

# Run the deployment
echo "Starting OpenStack deployment..."
ansible-playbook -i inventory/hosts playbooks/site.yml

echo "========================================"
echo "Deployment completed!"
echo "========================================"
echo ""
echo "Access your OpenStack dashboard at:"
echo "URL: http://$(grep controller inventory/hosts | cut -d'=' -f2)/horizon"
echo "Username: admin"
echo "Password: Check group_vars/all.yml for admin_password"
echo ""
echo "To create your first instance:"
echo "1. Log into Horizon dashboard"
echo "2. Go to Project > Compute > Instances"
echo "3. Click 'Launch Instance'"
echo ""
echo "For CLI access, source the credentials:"
echo "source /root/admin-openrc"
