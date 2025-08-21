# Simple OpenStack Setup Guide

## Overview
This guide provides a simplified OpenStack deployment using custom Ansible playbooks for a 3-node setup on GCP VMs.

## Prerequisites

### VM Setup on GCP
1. **Create 3 VMs** with the following specifications:
   - **OS**: Ubuntu 20.04 LTS
   - **RAM**: Minimum 4GB per VM (8GB recommended)
   - **Disk**: 20GB minimum per VM
   - **Network**: All VMs in the same VPC with internal connectivity

2. **VM Roles and IPs** (adjust in `inventory/hosts`):
   - Controller: 10.0.0.10
   - Storage: 10.0.0.20  
   - Compute: 10.0.0.30

### SSH Setup
1. **Generate SSH key** on controller node:
   ```bash
   ssh-keygen -t rsa -b 4096
   ```

2. **Copy SSH key** to all nodes:
   ```bash
   ssh-copy-id ubuntu@10.0.0.10  # controller
   ssh-copy-id ubuntu@10.0.0.20  # storage
   ssh-copy-id ubuntu@10.0.0.30  # compute
   ```

3. **Test SSH connectivity**:
   ```bash
   ssh ubuntu@10.0.0.20
   ssh ubuntu@10.0.0.30
   ```

## Installation Steps

### Step 1: Prepare Controller Node
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Ansible
sudo apt install -y ansible git

# Clone this repository
git clone <your-repo-url> openstack-simple
cd openstack-simple
```

### Step 2: Configure Inventory and Variables
1. **Edit inventory file** (`inventory/hosts`):
   ```ini
   [controller]
   controller ansible_host=YOUR_CONTROLLER_IP ansible_user=ubuntu

   [storage]
   storage ansible_host=YOUR_STORAGE_IP ansible_user=ubuntu

   [compute]
   compute ansible_host=YOUR_COMPUTE_IP ansible_user=ubuntu
   ```

2. **Update variables** in `group_vars/all.yml`:
   - Change IP addresses to match your VMs
   - Update passwords (recommended)
   - Adjust network interface names if needed

### Step 3: Test Connectivity
```bash
ansible all -i inventory/hosts -m ping
```

### Step 4: Deploy OpenStack
```bash
# Make deployment script executable (Linux)
chmod +x scripts/deploy.sh

# Run deployment
./scripts/deploy.sh

# Or run manually:
ansible-playbook -i inventory/hosts playbooks/site.yml
```

## Post-Installation

### Access Horizon Dashboard
1. Open browser and navigate to: `http://YOUR_CONTROLLER_IP/horizon`
2. Login credentials:
   - **Username**: admin
   - **Password**: openstack123 (or your custom password)
   - **Domain**: Default

### CLI Access
```bash
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

1. **SSH Connection Failed**:
   - Check VPC firewall rules
   - Verify SSH keys are properly copied
   - Ensure VMs can reach each other

2. **Service Start Failed**:
   - Check service logs: `journalctl -u <service-name>`
   - Verify database connectivity
   - Check configuration files for typos

3. **Database Connection Issues**:
   - Verify MySQL is running: `systemctl status mysql`
   - Check database passwords in configuration
   - Test database connectivity from other nodes

4. **Web Interface Not Accessible**:
   - Check Apache status: `systemctl status apache2`
   - Verify firewall settings
   - Check Horizon configuration

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

### For GCP VMs
1. **Enable nested virtualization** (if supported):
   ```bash
   # On compute node
   grep -E 'vmx|svm' /proc/cpuinfo
   # If present, change virt_type to "kvm" in group_vars/compute.yml
   ```

2. **Increase memory** if possible:
   - Controller: 8GB recommended
   - Storage: 4GB minimum
   - Compute: 8GB+ recommended

## Maintenance

### Regular Tasks
1. **Update packages**:
   ```bash
   ansible openstack -i inventory/hosts -b -m apt -a "upgrade=yes update_cache=yes"
   ```

2. **Backup databases**:
   ```bash
   mysqldump -u root -p --all-databases > openstack-backup.sql
   ```

3. **Monitor disk space**:
   ```bash
   df -h
   du -sh /var/lib/nova/instances/
   du -sh /var/lib/glance/images/
   ```

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