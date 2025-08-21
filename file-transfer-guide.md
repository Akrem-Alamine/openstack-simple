# File Transfer Guide: Windows to GCP VM

## Method 1: Using WinSCP (Recommended for Windows)

### Download and Install WinSCP:
1. Download from: https://winscp.net/eng/download.php
2. Install WinSCP

### Transfer Files:
1. Open WinSCP
2. Create new session:
   - Protocol: SFTP
   - Host name: Your GCP VM external IP
   - User name: your-username
   - Password: your-password (or use SSH key)
3. Connect and drag/drop the RIF folder to `/home/your-username/`

## Method 2: Using Git (Recommended)

### On Windows:
1. Create a GitHub repository
2. Upload your RIF folder to GitHub
3. Get the repository URL

### On GCP VM:
```bash
ssh username@your-gcp-vm-ip
git clone https://github.com/yourusername/your-repo.git openstack-simple
cd openstack-simple
chmod +x scripts/*.sh quick-setup.sh
```

## Method 3: Using PowerShell SCP

### Install OpenSSH Client on Windows (if not installed):
```powershell
# Run as Administrator
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

### Transfer files:
```powershell
# From PowerShell on Windows:
scp -r C:\Users\akrem\OneDrive\Desktop\RIF username@your-gcp-vm-ip:/home/username/openstack-simple
```

## Method 4: ZIP and Upload via GCP Console

### On Windows:
1. Right-click on RIF folder → Send to → Compressed folder
2. Upload RIF.zip via GCP Console file browser

### On GCP VM:
```bash
cd ~
unzip RIF.zip
mv RIF openstack-simple
cd openstack-simple
chmod +x scripts/*.sh quick-setup.sh
```

## What to Do After Transfer

### 1. Connect to your GCP VM:
```bash
ssh username@your-gcp-vm-external-ip
```

### 2. Navigate to the project:
```bash
cd openstack-simple
```

### 3. Run the quick setup:
```bash
chmod +x quick-setup.sh
./quick-setup.sh
```

### 4. The script will guide you through:
- Installing Ansible
- Detecting your VMs
- Setting up SSH keys
- Configuring IP addresses
- Testing connectivity
- Running the deployment

## Important: VM IP Discovery

### Find your VM IPs inside the GCP host:
```bash
# For libvirt/KVM VMs:
virsh list --all
virsh domifaddr controller
virsh domifaddr storage
virsh domifaddr compute

# For VirtualBox VMs:
VBoxManage list runningvms
VBoxManage guestproperty enumerate VM_NAME | grep IP

# General network check:
ip addr show
brctl show
```

### Common VM IP ranges:
- **libvirt/KVM**: 192.168.122.x
- **VirtualBox**: 192.168.56.x  
- **Docker**: 172.17.0.x

## Configuration Files to Update

### After transfer, edit these files with your actual VM IPs:

#### inventory/hosts:
```ini
[controller]
controller ansible_host=192.168.122.10 ansible_user=ubuntu

[storage]
storage ansible_host=192.168.122.20 ansible_user=ubuntu

[compute]
compute ansible_host=192.168.122.30 ansible_user=ubuntu
```

#### group_vars/all.yml:
```yaml
controller_ip: "192.168.122.10"
storage_ip: "192.168.122.20"
compute_ip: "192.168.122.30"
```

## Quick Commands Summary

```bash
# 1. Transfer files (choose one method above)
# 2. Connect to GCP VM
ssh username@your-gcp-vm-ip

# 3. Setup and deploy
cd openstack-simple
./quick-setup.sh

# 4. Or manual steps:
chmod +x scripts/*.sh
nano inventory/hosts          # Update VM IPs
nano group_vars/all.yml      # Update IP variables
ansible all -i inventory/hosts -m ping  # Test connectivity
./scripts/deploy.sh          # Deploy OpenStack
```

The quick-setup.sh script will help you discover your VM IPs and guide you through the entire process!
