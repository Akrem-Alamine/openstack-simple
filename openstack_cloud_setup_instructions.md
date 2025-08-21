# Simple OpenStack Setup Guide

## Overview
This guide provides a simplified OpenStack deployment using custom Ansible playbooks for a **1 GCP VM host** containing **3 internal VMs** for OpenStack services.

## Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    GCP VM Host                              │
│                  (Ubuntu 22.04 LTS)                        │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Controller  │  │   Storage   │  │   Compute   │         │
│  │    VM       │  │     VM      │  │     VM      │         │
│  │             │  │             │  │             │         │
│  │ • Keystone  │  │ • Cinder    │  │ • Nova      │         │
│  │ • Glance    │  │ • LVM       │  │ • Neutron   │         │
│  │ • Nova API  │  │ • iSCSI     │  │ • libvirt   │         │
│  │ • Neutron   │  │             │  │             │         │
│  │ • Horizon   │  │             │  │             │         │
│  │ • MySQL     │  │             │  │             │         │
│  │ • RabbitMQ  │  │             │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### GCP VM Host Setup
1. **Create 1 GCP VM** with the following specifications:
   - **OS**: Ubuntu 22.04 LTS
   - **RAM**: Minimum 16GB (24GB+ recommended)
   - **vCPUs**: 8 cores minimum (12+ recommended)
   - **Disk**: 100GB minimum (200GB+ recommended)
   - **Network**: Allow HTTP, HTTPS, SSH traffic
   - **Enable nested virtualization** (required for internal VMs)

2. **Internal VM Configuration**:
   - Controller VM: 192.168.122.10 (4GB RAM, 2 vCPUs, 20GB disk)
   - Storage VM: 192.168.122.20 (4GB RAM, 2 vCPUs, 20GB disk)  
   - Compute VM: 192.168.122.30 (6GB RAM, 4 vCPUs, 30GB disk)

### GCP VM Host Preparation
1. **Enable nested virtualization** when creating the GCP VM:
   ```bash
   # When creating VM via gcloud CLI:
   gcloud compute instances create openstack-host \
     --zone=us-central1-a \
     --machine-type=n1-standard-8 \
     --image-family=ubuntu-2204-lts \
     --image-project=ubuntu-os-cloud \
     --boot-disk-size=200GB \
     --enable-nested-virtualization \
     --tags=http-server,https-server
   ```

2. **Or enable via GCP Console**:
   - Go to Compute Engine → VM instances
   - Create instance → Advanced options
   - CPU platform and GPU → Enable "Turn on vTPM"
   - Enable nested virtualization

### Internal VM Setup
1. **Connect to your GCP VM host**:
   ```bash
   # From your local machine
   ssh username@YOUR-GCP-VM-EXTERNAL-IP
   ```

2. **Install virtualization software**:
   ```bash
   # Update system
   sudo apt update && sudo apt upgrade -y
   
   # Install KVM/QEMU and tools
   sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager virtinst virt-viewer
   
   # Add user to libvirt group
   sudo usermod -aG libvirt $USER
   sudo usermod -aG kvm $USER
   
   # Restart to apply group changes
   sudo reboot
   ```

3. **Verify nested virtualization**:
   ```bash
   # After reboot, check if nested virtualization is enabled
   egrep -c '(vmx|svm)' /proc/cpuinfo
   # Should return a number > 0
   
   # Check KVM acceleration
   kvm-ok
   # Should show "KVM acceleration can be used"
   ```

4. **Download Ubuntu 20.04 ISO**:
   ```bash
   # Create directory for ISOs
   mkdir -p ~/isos
   cd ~/isos
   
   # Download Ubuntu 20.04 Server ISO
   wget https://releases.ubuntu.com/20.04/ubuntu-20.04.6-live-server-amd64.iso
   ```

5. **Create the 3 internal VMs**:
   ```bash
   # Create storage directory for VMs
   sudo mkdir -p /var/lib/libvirt/images
   
   # Create Controller VM
   sudo virt-install \
     --name controller \
     --ram 4096 \
     --vcpus 2 \
     --disk path=/var/lib/libvirt/images/controller.qcow2,size=20 \
     --os-type linux \
     --os-variant ubuntu20.04 \
     --network bridge=virbr0 \
     --graphics none \
     --console pty,target_type=serial \
     --location ~/isos/ubuntu-20.04.6-live-server-amd64.iso \
     --extra-args 'console=ttyS0,115200n8 serial'
   
   # Create Storage VM
   sudo virt-install \
     --name storage \
     --ram 4096 \
     --vcpus 2 \
     --disk path=/var/lib/libvirt/images/storage.qcow2,size=20 \
     --disk path=/var/lib/libvirt/images/storage-extra.qcow2,size=20 \
     --os-type linux \
     --os-variant ubuntu20.04 \
     --network bridge=virbr0 \
     --graphics none \
     --console pty,target_type=serial \
     --location ~/isos/ubuntu-20.04.6-live-server-amd64.iso \
     --extra-args 'console=ttyS0,115200n8 serial'
   
   # Create Compute VM
   sudo virt-install \
     --name compute \
     --ram 6144 \
     --vcpus 4 \
     --disk path=/var/lib/libvirt/images/compute.qcow2,size=30 \
     --os-type linux \
     --os-variant ubuntu20.04 \
     --network bridge=virbr0 \
     --graphics none \
     --console pty,target_type=serial \
     --location ~/isos/ubuntu-20.04.6-live-server-amd64.iso \
     --extra-args 'console=ttyS0,115200n8 serial'
   ```

6. **Configure each VM during installation**:
   - Set hostname: `controller`, `storage`, `compute`
   - Create user: `ubuntu` with password
   - Enable SSH server
   - Install OpenSSH server
   - Set static IP addresses (or note DHCP assigned IPs)

### VM Management Commands
```bash
# List all VMs
virsh list --all

# Start VMs
virsh start controller
virsh start storage
virsh start compute

# Get VM IP addresses
virsh domifaddr controller
virsh domifaddr storage
virsh domifaddr compute

# Connect to VM console
virsh console controller
# (Press Ctrl+] to exit console)

# Shutdown VMs
virsh shutdown controller
virsh shutdown storage
virsh shutdown compute

# Force stop VMs (if needed)
virsh destroy controller
```

## Installation Steps

### Step 1: Prepare GCP VM Host for Ansible
```bash
# On your GCP VM host, install Ansible and Git
sudo apt update && sudo apt upgrade -y
sudo apt install -y ansible git python3-pip

# Clone the OpenStack repository
git clone https://github.com/Akrem-Alamine/openstack-simple.git
cd openstack-simple
```

### Step 2: Discover Internal VM IPs
```bash
# Find the IP addresses of your internal VMs
virsh domifaddr controller
virsh domifaddr storage
virsh domifaddr compute

# Or check the default libvirt network
ip addr show virbr0
virsh net-dhcp-leases default
```

### Step 3: Configure Inventory and Variables
1. **Edit inventory file** (`inventory/hosts`):
   ```ini
   [controller]
   controller ansible_host=192.168.122.10 ansible_user=ubuntu

   [storage]
   storage ansible_host=192.168.122.20 ansible_user=ubuntu

   [compute]
   compute ansible_host=192.168.122.30 ansible_user=ubuntu
   
   [openstack:children]
   controller
   storage
   compute
   ```

2. **Update variables** in `group_vars/all.yml`:
   ```yaml
   # Controller node info (update with actual IPs)
   controller_ip: "192.168.122.10"
   storage_ip: "192.168.122.20"
   compute_ip: "192.168.122.30"
   
   # Network interfaces (common for libvirt VMs)
   management_interface: "enp1s0"
   provider_interface: "enp1s0"
   ```

### Step 4: Setup SSH Access from Host to VMs
```bash
# Generate SSH key on GCP VM host
ssh-keygen -t rsa -b 4096 -f ~/.ssh/openstack_key

# Copy SSH key to all internal VMs
ssh-copy-id -i ~/.ssh/openstack_key ubuntu@192.168.122.10
ssh-copy-id -i ~/.ssh/openstack_key ubuntu@192.168.122.20
ssh-copy-id -i ~/.ssh/openstack_key ubuntu@192.168.122.30

# Test SSH connectivity
ssh -i ~/.ssh/openstack_key ubuntu@192.168.122.10
ssh -i ~/.ssh/openstack_key ubuntu@192.168.122.20
ssh -i ~/.ssh/openstack_key ubuntu@192.168.122.30
```

### Step 5: Test Ansible Connectivity
```bash
# Update ansible.cfg to use the correct SSH key
echo "private_key_file = ~/.ssh/openstack_key" >> ansible.cfg

# Test Ansible connectivity
ansible all -i inventory/hosts -m ping
```

### Step 6: Deploy OpenStack
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run the deployment
./scripts/deploy.sh

# Or run manually:
ansible-playbook -i inventory/hosts playbooks/site.yml
```

## Post-Installation

### Access Horizon Dashboard
1. **From inside GCP VM host**:
   ```bash
   # Check controller VM IP
   CONTROLLER_IP=$(virsh domifaddr controller | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)
   echo "Controller IP: $CONTROLLER_IP"
   
   # Test local access
   curl http://$CONTROLLER_IP/horizon
   ```

2. **From your local machine** (requires port forwarding):
   ```bash
   # On your local machine, create SSH tunnel
   ssh -L 8080:192.168.122.10:80 username@YOUR-GCP-VM-EXTERNAL-IP
   
   # Then access: http://localhost:8080/horizon
   ```

3. **Login credentials**:
   - **Username**: admin
   - **Password**: openstack123 (or your custom password)
   - **Domain**: Default

### CLI Access
```bash
# SSH into controller VM
ssh -i ~/.ssh/openstack_key ubuntu@192.168.122.10

# Source admin credentials
source /root/admin-openrc

# Test OpenStack services
openstack service list
openstack image list
openstack flavor list
```

### Create Your First Instance
1. **Via Horizon**:
   - Go to Project → Compute → Instances
   - Click "Launch Instance"
   - Select cirros image and m1.nano flavor

2. **Via CLI**:
   ```bash
   source /root/demo-openrc
   openstack server create --flavor m1.nano --image cirros --security-group default test-instance
   ```

## Troubleshooting

### Common Issues

1. **Internal VMs Not Accessible**:
   ```bash
   # Check VM status
   virsh list --all
   
   # Start VMs if stopped
   virsh start controller
   virsh start storage
   virsh start compute
   
   # Check libvirt network
   virsh net-list
   virsh net-info default
   ```

2. **Nested Virtualization Issues**:
   ```bash
   # On GCP VM host, verify nested virtualization
   egrep -c '(vmx|svm)' /proc/cpuinfo
   kvm-ok
   
   # If not working, check GCP VM settings
   # May need to recreate VM with nested virtualization enabled
   ```

3. **Network Connectivity Between VMs**:
   ```bash
   # Check bridge network
   brctl show virbr0
   ip addr show virbr0
   
   # Test connectivity between VMs
   ssh -i ~/.ssh/openstack_key ubuntu@192.168.122.10
   ping 192.168.122.20  # from controller to storage
   ping 192.168.122.30  # from controller to compute
   ```

4. **SSH Key Issues**:
   ```bash
   # Regenerate SSH keys if needed
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/openstack_key
   
   # Copy to all VMs again
   for vm in 192.168.122.10 192.168.122.20 192.168.122.30; do
     ssh-copy-id -i ~/.ssh/openstack_key ubuntu@$vm
   done
   ```

5. **DNS Issues on GCP VM Host**:
   ```bash
   # Fix DNS resolution
   echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
   echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
   
   # Update package sources if needed
   sudo sed -i 's/us-central1\.gce\.archive\.ubuntu\.com/archive.ubuntu.com/g' /etc/apt/sources.list
   sudo apt update
   ```

6. **Memory/Resource Issues**:
   ```bash
   # Check host resources
   free -h
   df -h
   
   # Check VM resource allocation
   virsh dominfo controller
   virsh dominfo storage
   virsh dominfo compute
   
   # Adjust VM memory if needed
   virsh setmaxmem controller 6G --config
   virsh setmem controller 6G --config
   ```

### VM Management Commands
```bash
# Check VM status
virsh list --all

# Get VM IP addresses
virsh domifaddr controller
virsh domifaddr storage
virsh domifaddr compute

# Connect to VM console
virsh console controller

# Monitor VM resources
virsh domstats --all

# Backup VM
virsh dumpxml controller > controller-backup.xml
```

### Useful Commands
```bash
# Check service status
systemctl status keystone
systemctl status glance-api
systemctl status nova-api
systemctl status neutron-server

# View service logs
journalctl -u keystone -f
journalctl -u glance-api -f

# Restart services
systemctl restart apache2
systemctl restart mysql

# Check OpenStack services
openstack service list
openstack endpoint list
openstack compute service list
openstack network agent list
```

## Cleanup
To remove the entire OpenStack installation:
```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

## Network Configuration

### Provider Network (Optional)
If you want external connectivity:

1. **Create provider network**:
   ```bash
   openstack network create --share --external --provider-physical-network provider --provider-network-type flat provider
   ```

2. **Create subnet**:
   ```bash
   openstack subnet create --network provider --allocation-pool start=10.0.1.100,end=10.0.1.200 --dns-nameserver 8.8.8.8 --gateway 10.0.1.1 --subnet-range 10.0.1.0/24 provider-subnet
   ```

### Security Groups
Default security group allows SSH and ping. To add more rules:
```bash
openstack security group rule create --proto tcp --dst-port 80 default
openstack security group rule create --proto tcp --dst-port 443 default
```

## Performance Optimization

### For GCP VM Host with Internal VMs
1. **GCP VM Host Requirements**:
   - **RAM**: 16GB minimum (24GB+ recommended)
   - **vCPUs**: 8 cores minimum (12+ recommended)  
   - **Disk**: 200GB+ recommended
   - **Nested virtualization**: Required and enabled

2. **Internal VM Resource Allocation**:
   ```bash
   # Check current allocation
   virsh dominfo controller | grep -E "Max memory|Used memory|CPU"
   
   # Modify VM resources if needed (VMs must be shut down)
   virsh shutdown controller
   virsh setmaxmem controller 6G --config
   virsh setvcpus controller 4 --config --maximum
   virsh start controller
   ```

3. **Enable nested virtualization for compute VM**:
   ```bash
   # Edit compute VM configuration
   virsh edit compute
   
   # Add/modify in the <cpu> section:
   # <cpu mode='host-passthrough' check='none'/>
   ```

## Maintenance

### Regular Tasks
1. **Update packages on host and VMs**:
   ```bash
   # Update GCP VM host
   sudo apt update && sudo apt upgrade -y
   
   # Update internal VMs via Ansible
   ansible openstack -i inventory/hosts -b -m apt -a "upgrade=yes update_cache=yes"
   ```

2. **Backup VMs and databases**:
   ```bash
   # Backup VM configurations
   virsh dumpxml controller > controller-backup.xml
   virsh dumpxml storage > storage-backup.xml
   virsh dumpxml compute > compute-backup.xml
   
   # Backup VM disks (VMs should be shut down)
   cp /var/lib/libvirt/images/controller.qcow2 /backup/
   
   # Backup OpenStack databases
   ssh -i ~/.ssh/openstack_key ubuntu@192.168.122.10
   mysqldump -u root -p --all-databases > openstack-backup.sql
   ```

3. **Monitor resources**:
   ```bash
   # Monitor host resources
   htop
   df -h
   
   # Monitor VM resources
   virsh domstats --all
   
   # Check OpenStack service status
   ansible controller -i inventory/hosts -m shell -a "systemctl status keystone glance-api nova-api neutron-server"
   ```

## Quick Start Summary

### For Existing 3 Internal VMs:
```bash
# 1. Connect to GCP VM host
ssh username@YOUR-GCP-VM-EXTERNAL-IP

# 2. Clone repository
git clone https://github.com/Akrem-Alamine/openstack-simple.git
cd openstack-simple

# 3. Find VM IPs
virsh domifaddr controller
virsh domifaddr storage  
virsh domifaddr compute

# 4. Configure files
nano inventory/hosts        # Update with actual VM IPs
nano group_vars/all.yml     # Update IP variables

# 5. Setup SSH and deploy
ssh-keygen -t rsa -b 4096 -f ~/.ssh/openstack_key
# Copy SSH keys to VMs
ansible all -i inventory/hosts -m ping
./scripts/deploy.sh
```

### For New VM Creation:
Follow the complete guide above starting from "GCP VM Host Preparation"

## Next Steps
1. Install additional services (Heat, Swift, etc.)
2. Configure external networking
3. Set up monitoring (Prometheus + Grafana)
4. Implement backup strategies
5. Learn about OpenStack operations

## Support
For issues and questions:
1. Check OpenStack documentation
2. Review service logs
3. Test connectivity between nodes
4. Verify configuration files