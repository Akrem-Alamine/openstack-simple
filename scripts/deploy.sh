#!/bin/bash

# Simple OpenStack Deployment Script
set -e

echo "========================================"
echo "Simple OpenStack Deployment Starting..."
echo "========================================"

# Check Ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo "Installing Ansible..."
    sudo apt update
    sudo apt install -y ansible
fi

# Test connectivity
echo "Testing VM connectivity..."
ansible all -i inventory/hosts -m ping || {
    echo "ERROR: Cannot reach VMs. Check:"
    echo "1. VMs are running: virsh list"
    echo "2. IPs are correct in inventory/hosts"
    echo "3. Password ubuntu123 works"
    exit 1
}

echo "Starting OpenStack deployment..."
ansible-playbook -i inventory/hosts playbooks/site.yml

echo "========================================"
echo "Deployment completed!"
echo "========================================"
echo "Access Horizon:"
echo "1. Get controller IP: virsh domifaddr controller"
echo "2. SSH tunnel: ssh -L 8080:CONTROLLER_IP:80 username@YOUR-GCP-VM"
echo "3. Open: http://localhost:8080/horizon"
echo "4. Login: admin / openstack123"

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
