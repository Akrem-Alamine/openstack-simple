# Simple OpenStack Setup - 24GB GCP VM

## Quick Start (30 minutes)

### 1. Create GCP VM
```bash
gcloud compute instances create openstack-host \
  --zone=us-east1-c \
  --machine-type=n1-standard-8 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=200GB \
  --enable-nested-virtualization \
  --tags=http-server,https-server
```

### 2. SSH to GCP VM and run automated setup
```bash
ssh username@YOUR-GCP-VM-IP

# Download and run setup script
wget https://raw.githubusercontent.com/Akrem-Alamine/openstack-simple/main/quick-setup.sh
chmod +x quick-setup.sh
./quick-setup.sh
```

### 3. Deploy OpenStack
```bash
cd openstack-simple
./scripts/deploy.sh
```

### 4. Access Dashboard
```bash
# Get controller IP
CONTROLLER_IP=$(virsh domifaddr controller | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)
echo "Controller IP: $CONTROLLER_IP"

# From your local machine, create SSH tunnel:
ssh -L 8080:$CONTROLLER_IP:80 username@YOUR-GCP-VM-IP

# Open browser: http://localhost:8080/horizon
# Login: admin / openstack123
```

## VM Specifications (Optimized for 24GB Host)
- **Controller**: 6GB RAM, 3 vCPUs, 50GB disk
- **Storage**: 4GB RAM, 2 vCPUs, 30GB disk  
- **Compute**: 8GB RAM, 4 vCPUs, 60GB disk
- **Total used**: 18GB RAM, 140GB disk

## Default Passwords (Simple!)
- **VM SSH**: ubuntu / ubuntu123
- **OpenStack Admin**: admin / openstack123
- **PostgreSQL**: (local peer auth for 'postgres', service DB user passwords stored in group_vars)

## Quick Commands
```bash
# VM management
virsh list --all                    # List all VMs
virsh domifaddr controller          # Get VM IP
ssh ubuntu@VM_IP                    # SSH to VM (password: ubuntu123)

# OpenStack management
ssh ubuntu@CONTROLLER_IP
source /root/admin-openrc
openstack service list
```

## Troubleshooting
1. **VMs not starting**: Check `virsh list --all`, wait 5 minutes after creation
2. **Cannot SSH**: Password is `ubuntu123`, wait for cloud-init to complete
3. **Deployment fails**: Check `ansible all -i inventory/hosts -m ping`

## What's Different from Original
- ✅ **Simplified cloud-init** with plain text passwords
- ✅ **Optimized VM sizes** for 24GB host
- ✅ **Password authentication** instead of SSH keys
- ✅ **Automated IP discovery** and configuration
- ✅ **Single script setup** for everything
- ✅ **Clear resource allocation** (18GB RAM used from 24GB)

## Architecture
```
GCP VM Host (24GB RAM, 200GB SSD)
├── Controller VM (6GB RAM) - Keystone, Glance, Nova API, Neutron, Horizon, PostgreSQL
├── Storage VM (4GB RAM)    - Cinder, LVM, iSCSI
└── Compute VM (8GB RAM)    - Nova Compute, Neutron Agent, libvirt
```

Total setup time: **~30 minutes**
