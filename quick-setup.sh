#!/bin/bash

# Simple OpenStack Setup for GCP VM (24GB RAM, 200GB storage)
set -e

echo "========================================="
echo "Simple OpenStack Setup for GCP VM"
echo "24GB RAM / 200GB Storage Optimized"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}==== $1 ====${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# Step 1: Install prerequisites
print_step "Installing Prerequisites"
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager ansible git
sudo usermod -aG libvirt $USER
print_success "Prerequisites installed"

# Step 2: Download Ubuntu cloud image
print_step "Downloading Ubuntu 22.04 Cloud Image"
mkdir -p ~/images && cd ~/images
if [ ! -f jammy-server-cloudimg-amd64.img ]; then
    wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
fi
print_success "Cloud image ready"

# Step 3: Create simple cloud-init files
print_step "Creating Cloud-Init Files"
mkdir -p ~/cloud-init

# Controller cloud-init
cat > ~/cloud-init/controller-user-data.yaml << 'EOF'
#cloud-config
hostname: controller
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    plain_text_passwd: ubuntu123
    lock_passwd: false
packages:
  - openssh-server
  - python3
  - qemu-guest-agent
ssh_pwauth: true
runcmd:
  - systemctl enable ssh
  - systemctl start ssh
EOF

# Storage cloud-init  
cat > ~/cloud-init/storage-user-data.yaml << 'EOF'
#cloud-config
hostname: storage
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    plain_text_passwd: ubuntu123
    lock_passwd: false
packages:
  - openssh-server
  - python3
  - qemu-guest-agent
  - lvm2
ssh_pwauth: true
runcmd:
  - systemctl enable ssh
  - systemctl start ssh
EOF

# Compute cloud-init
cat > ~/cloud-init/compute-user-data.yaml << 'EOF'
#cloud-config
hostname: compute
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    plain_text_passwd: ubuntu123
    lock_passwd: false
packages:
  - openssh-server
  - python3
  - qemu-guest-agent
ssh_pwauth: true
runcmd:
  - systemctl enable ssh
  - systemctl start ssh
EOF

print_success "Cloud-init files created"

# Step 4: Create VM disks
print_step "Creating VM Disk Images"
sudo mkdir -p /var/lib/libvirt/images

# Copy and resize images for 24GB host (6+4+8 = 18GB RAM used)
sudo cp ~/images/jammy-server-cloudimg-amd64.img /var/lib/libvirt/images/controller.qcow2
sudo cp ~/images/jammy-server-cloudimg-amd64.img /var/lib/libvirt/images/storage.qcow2  
sudo cp ~/images/jammy-server-cloudimg-amd64.img /var/lib/libvirt/images/compute.qcow2

# Resize for 200GB host (50+30+60 = 140GB used)
sudo qemu-img resize /var/lib/libvirt/images/controller.qcow2 50G
sudo qemu-img resize /var/lib/libvirt/images/storage.qcow2 30G
sudo qemu-img resize /var/lib/libvirt/images/compute.qcow2 60G

# Storage extra disk
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/storage-extra.qcow2 20G

# Copy cloud-init files
sudo cp ~/cloud-init/*-user-data.yaml /var/lib/libvirt/images/
sudo chown -R libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/

print_success "VM disks created"

# Step 5: Create VMs
print_step "Creating Virtual Machines"

# Controller VM (6GB RAM, 3 vCPUs)
sudo virt-install \
  --name controller \
  --ram 6144 --vcpus 3 \
  --disk path=/var/lib/libvirt/images/controller.qcow2,format=qcow2 \
  --os-variant ubuntu22.04 --virt-type kvm --graphics none \
  --network network=default \
  --import \
  --cloud-init user-data=/var/lib/libvirt/images/controller-user-data.yaml \
  --noautoconsole

# Storage VM (4GB RAM, 2 vCPUs)  
sudo virt-install \
  --name storage \
  --ram 4096 --vcpus 2 \
  --disk path=/var/lib/libvirt/images/storage.qcow2,format=qcow2 \
  --disk path=/var/lib/libvirt/images/storage-extra.qcow2,format=qcow2 \
  --os-variant ubuntu22.04 --virt-type kvm --graphics none \
  --network network=default \
  --import \
  --cloud-init user-data=/var/lib/libvirt/images/storage-user-data.yaml \
  --noautoconsole

# Compute VM (8GB RAM, 4 vCPUs)
sudo virt-install \
  --name compute \
  --ram 8192 --vcpus 4 \
  --disk path=/var/lib/libvirt/images/compute.qcow2,format=qcow2 \
  --os-variant ubuntu22.04 --virt-type kvm --graphics none \
  --network network=default \
  --import \
  --cloud-init user-data=/var/lib/libvirt/images/compute-user-data.yaml \
  --noautoconsole

print_success "VMs created successfully"

# Step 6: Wait for VMs to boot
print_step "Waiting for VMs to Boot (5 minutes)"
sleep 300

# Step 7: Show VM status and IPs
print_step "VM Status and IPs"
virsh list --all

echo -e "\nGetting VM IP addresses..."
CONTROLLER_IP=$(virsh domifaddr controller | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)
STORAGE_IP=$(virsh domifaddr storage | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)
COMPUTE_IP=$(virsh domifaddr compute | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)

echo "Controller IP: $CONTROLLER_IP"
echo "Storage IP: $STORAGE_IP"
echo "Compute IP: $COMPUTE_IP"

# Step 8: Clone OpenStack repository
print_step "Setting up OpenStack Configuration"
if [ ! -d "openstack-simple" ]; then
    git clone https://github.com/Akrem-Alamine/openstack-simple.git
fi
cd openstack-simple

# Update inventory with actual IPs
cat > inventory/hosts << EOF
[controller]
controller ansible_host=$CONTROLLER_IP ansible_user=ubuntu ansible_password=ubuntu123

[storage]
storage ansible_host=$STORAGE_IP ansible_user=ubuntu ansible_password=ubuntu123

[compute]
compute ansible_host=$COMPUTE_IP ansible_user=ubuntu ansible_password=ubuntu123

[openstack:children]
controller
storage
compute
EOF

# Update group vars
cat > group_vars/all.yml << EOF
# OpenStack Simple Configuration
openstack_release: "yoga"

# Simple passwords
admin_password: "openstack123"
database_password: "db_pass123"
rabbit_password: "rabbit_pass123"

# Service passwords
keystone_db_password: "keystone_pass123"
glance_db_password: "glance_pass123"
nova_db_password: "nova_pass123"
neutron_db_password: "neutron_pass123"
cinder_db_password: "cinder_pass123"
glance_password: "glance_pass123"
nova_password: "nova_pass123"
neutron_password: "neutron_pass123"
cinder_password: "cinder_pass123"

# Network interface
management_interface: "enp1s0"
provider_interface: "enp1s0"

# Node IPs
controller_ip: "$CONTROLLER_IP"
storage_ip: "$STORAGE_IP"
compute_ip: "$COMPUTE_IP"

# Connection strings
transport_url: "rabbit://openstack:rabbit_pass123@$CONTROLLER_IP:5672/"
auth_url: "http://$CONTROLLER_IP:5000/v3"

# Admin settings
admin_project_name: "admin"
admin_username: "admin"
timezone: "UTC"
EOF

print_success "Configuration updated"

# Step 9: Test connectivity
print_step "Testing Connectivity"
if ansible all -i inventory/hosts -m ping; then
    print_success "All VMs are accessible"
else
    print_error "Some VMs are not accessible. Wait a few more minutes and try again."
    exit 1
fi

# Final instructions
echo -e "\n${GREEN}========================================="
echo "Setup Complete!"
echo "=========================================${NC}"
echo -e "VMs created with ${YELLOW}24GB host optimization${NC}:"
echo "• Controller: 6GB RAM, 3 vCPUs, 50GB disk"
echo "• Storage: 4GB RAM, 2 vCPUs, 30GB disk"  
echo "• Compute: 8GB RAM, 4 vCPUs, 60GB disk"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Deploy OpenStack:"
echo "   cd openstack-simple && ./scripts/deploy.sh"
echo ""
echo "2. Access Horizon dashboard:"
echo "   ssh -L 8080:$CONTROLLER_IP:80 username@YOUR-GCP-VM-IP"
echo "   Open: http://localhost:8080/horizon"
echo "   Login: admin / openstack123"
echo ""
echo -e "${BLUE}VM Management:${NC}"
echo "• List VMs: virsh list --all"
echo "• VM IPs: virsh domifaddr VM_NAME"
echo "• SSH to VM: ssh ubuntu@VM_IP (password: ubuntu123)"
echo ""
echo -e "${GREEN}Total setup time: ~30 minutes${NC}"

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

# Step 6: Check for VMs with fixed IPs
print_step "Checking Virtual Machines"

echo "Checking for VMs with fixed IP configuration..."

# Check if VMs exist
if virsh list --all | grep -q "controller\|storage\|compute"; then
    echo "Found existing VMs:"
    virsh list --all | grep -E "controller|storage|compute"
    VM_EXISTS=true
else
    echo "No OpenStack VMs found. You'll need to create them first."
    VM_EXISTS=false
fi

# Step 7: VM Creation guidance
if [ "$VM_EXISTS" = false ]; then
    print_step "VM Creation Required"
    echo "Please create VMs using the new Ubuntu 22.04 approach:"
    echo ""
    echo "1. Download Ubuntu 22.04 cloud image:"
    echo "   sudo wget -O jammy-server-cloudimg-amd64.img \\"
    echo "     https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    echo ""
    echo "2. Create cloud-init files with fixed IPs (192.168.122.10, 20, 30)"
    echo "3. Use new virt-install commands with --cloud-init option"
    echo ""
    read -p "Press Enter after you've created the VMs..."
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

# Step 9: Configuration setup with fixed IPs
print_step "Configuration Setup"

echo "VMs should be configured with fixed IPs:"
echo "- Controller: 192.168.122.10"
echo "- Storage: 192.168.122.20"
echo "- Compute: 192.168.122.30"
echo ""
echo "Please verify the following files:"
echo ""
echo "1. inventory/hosts - should contain the fixed IPs"
echo "2. group_vars/all.yml - should match the IP configuration"
echo ""

read -p "Press Enter after you've verified the configuration files..."

# Step 10: Test connectivity with fixed IPs
print_step "Testing VM Connectivity"

echo "Testing SSH connectivity to VMs with fixed IPs..."

# Test connectivity to fixed IPs
CONTROLLER_IP="192.168.122.10"
STORAGE_IP="192.168.122.20"
COMPUTE_IP="192.168.122.30"

echo "Testing Controller ($CONTROLLER_IP)..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$CONTROLLER_IP "hostname" 2>/dev/null; then
    print_success "Controller VM reachable"
else
    print_error "Controller VM not reachable"
fi

echo "Testing Storage ($STORAGE_IP)..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$STORAGE_IP "hostname" 2>/dev/null; then
    print_success "Storage VM reachable"
else
    print_error "Storage VM not reachable"
fi

echo "Testing Compute ($COMPUTE_IP)..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$COMPUTE_IP "hostname" 2>/dev/null; then
    print_success "Compute VM reachable"
else
    print_error "Compute VM not reachable"
fi

# Test Ansible connectivity
if ansible all -i inventory/hosts -m ping --private-key "$SSH_KEY" > /dev/null 2>&1; then
    print_success "All VMs are reachable via Ansible!"
else
    print_error "Some VMs are not reachable via Ansible"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Verify VMs are running: virsh list"
    echo "2. Check cloud-init completion: ssh ubuntu@VM_IP 'sudo cloud-init status'"
    echo "3. Verify SSH keys are configured in cloud-init files"
    echo "4. Check network configuration: ssh ubuntu@VM_IP 'ip addr show'"
    echo ""
    read -p "Fix the issues and press Enter to continue..."
fi

# Step 11: Final deployment prompt
print_step "Ready for Deployment"

echo "System is ready for OpenStack deployment!"
echo ""
echo "VM Configuration:"
echo "- Controller: $CONTROLLER_IP (Ubuntu 22.04)"
echo "- Storage: $STORAGE_IP (Ubuntu 22.04)"  
echo "- Compute: $COMPUTE_IP (Ubuntu 22.04)"
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
