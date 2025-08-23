# OpenStack Deployment Commands for GCP VM Host

## Step 1: Transfer Files to Your GCP VM Host

Since you're on Windows and need to get these files to your GCP VM host, you have several options:

### Option A: Using Git (Recommended)
```bash
# On your GCP VM host (controller node):
sudo apt update
sudo apt install -y git ansible
git clone https://github.com/YOURUSERNAME/openstack-simple.git
cd openstack-simple
```

**Note**: Replace `YOURUSERNAME` with your actual GitHub username after creating the repository.

### Option B: Using SCP from Windows
```powershell
# From your Windows machine:
scp -r C:\Users\akrem\OneDrive\Desktop\RIF username@your-gcp-vm-ip:/home/username/openstack-simple
```

### Option C: Manual Upload
1. Zip the RIF folder
2. Upload via GCP Console or FileZilla
3. Extract on the GCP VM

## Step 2: Prepare Your GCP VM Host

### Connect to your GCP VM host:
```bash
# From your Windows machine:
ssh username@your-gcp-vm-external-ip
```

### Install prerequisites:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ansible git python3-pip
```

## Step 3: Configure Your 3 Internal VMs

### Check your VMs are running:
```bash
# List running VMs (adjust based on your virtualization platform)
virsh list --all  # if using KVM/libvirt
docker ps -a      # if using Docker
VBoxManage list vms  # if using VirtualBox
```

### Get VM IP addresses:
```bash
# Find IP addresses of your 3 VMs
ip addr show        # Check host interfaces
virsh domifaddr controller  # if using libvirt
virsh domifaddr storage
virsh domifaddr compute
```

## Step 4: Update Configuration Files

### Edit inventory file:
```bash
cd openstack-simple
nano inventory/hosts
```

Update with your actual VM IPs:
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

### Update variables:
```bash
nano group_vars/all.yml
```

Change these values:
```yaml
# Controller node info
controller_ip: "192.168.122.10"  # Your controller VM IP
storage_ip: "192.168.122.20"     # Your storage VM IP
compute_ip: "192.168.122.30"     # Your compute VM IP

# Network interfaces - check with 'ip addr' on your VMs
management_interface: "ens3"      # Common for KVM VMs
provider_interface: "ens4"       # Secondary interface if available
```

## Step 5: Setup SSH Access

### Generate SSH key on host:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/openstack_key
```

### Copy SSH key to all VMs:
```bash
# For each VM:
ssh-copy-id -i ~/.ssh/openstack_key ubuntu@192.168.122.10
ssh-copy-id -i ~/.ssh/openstack_key ubuntu@192.168.122.20
ssh-copy-id -i ~/.ssh/openstack_key ubuntu@192.168.122.30
```

### Test connectivity:
```bash
ansible all -i inventory/hosts -m ping --private-key ~/.ssh/openstack_key
```

## Step 6: Pre-deployment Checks

### Verify VM resources:
```bash
# Check each VM has enough resources
ansible all -i inventory/hosts -m shell -a "free -h" --private-key ~/.ssh/openstack_key
ansible all -i inventory/hosts -m shell -a "df -h" --private-key ~/.ssh/openstack_key
```

### Check Ubuntu version:
```bash
ansible all -i inventory/hosts -m shell -a "lsb_release -a" --private-key ~/.ssh/openstack_key
```

## Step 7: Deploy OpenStack

### Make scripts executable:
```bash
chmod +x scripts/*.sh
```

### Run the deployment:
```bash
# Option 1: Use the deployment script
./scripts/deploy.sh

# Option 2: Run manually with custom SSH key
ansible-playbook -i inventory/hosts playbooks/site.yml --private-key ~/.ssh/openstack_key

# Option 3: Run step by step for debugging
ansible-playbook -i inventory/hosts playbooks/00-prerequisites.yml --private-key ~/.ssh/openstack_key
ansible-playbook -i inventory/hosts playbooks/01-database.yml --private-key ~/.ssh/openstack_key
# ... continue with each playbook
```

## Step 8: Monitor Deployment

### Watch deployment progress:
```bash
# In another terminal, monitor logs:
tail -f /var/log/ansible.log

# Or check specific services:
ansible controller -i inventory/hosts -m shell -a "systemctl status postgresql" --private-key ~/.ssh/openstack_key
ansible controller -i inventory/hosts -m shell -a "systemctl status apache2" --private-key ~/.ssh/openstack_key
```

## Step 9: Post-Deployment Validation

### Run validation script:
```bash
./scripts/validate.sh
```

### Test web access:
```bash
# Get controller IP for web access
CONTROLLER_IP=$(grep controller inventory/hosts | cut -d'=' -f2)
echo "Access Horizon at: http://$CONTROLLER_IP/horizon"
```

### If accessing from outside GCP VM:
You'll need to set up port forwarding or configure GCP firewall rules:
```bash
# Port forwarding from GCP VM to your local machine:
ssh -L 8080:192.168.122.10:80 username@your-gcp-vm-external-ip

# Then access: http://localhost:8080/horizon
```

## Troubleshooting Common Issues

### VMs not accessible:
```bash
# Check VM status
virsh list --all
systemctl status libvirtd

# Start VMs if needed
virsh start controller
virsh start storage  
virsh start compute
```

### Network connectivity issues:
```bash
# Check VM networks
virsh net-list
virsh net-info default

# Check bridge interfaces
brctl show
ip addr show virbr0
```

### SSH key issues:
```bash
# Update ansible.cfg with correct key
echo "private_key_file = ~/.ssh/openstack_key" >> ansible.cfg

# Or specify in command
ansible-playbook -i inventory/hosts playbooks/site.yml --private-key ~/.ssh/openstack_key
```

### Memory/disk space issues:
```bash
# Check resources on each VM
ansible all -i inventory/hosts -m shell -a "free -m && df -h" --private-key ~/.ssh/openstack_key
```

## Expected Timeline

- Prerequisites: 10-15 minutes
- SSH setup: 5-10 minutes  
- Deployment: 30-45 minutes
- Validation: 5 minutes

Total: ~1 hour for complete setup

## Success Indicators

1. ✅ All VMs respond to ping
2. ✅ SSH connectivity works
3. ✅ Ansible can reach all nodes
4. ✅ All services start successfully
5. ✅ Horizon dashboard accessible
6. ✅ Can create test instance

## Next Steps After Successful Deployment

1. Access Horizon dashboard
2. Create your first OpenStack project
3. Upload custom images
4. Configure networking
5. Launch instances
6. Set up monitoring
