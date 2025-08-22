# Simple OpenStack Setup Guide (Updated to Match Current Working Steps)

## Overview
This updated guide matches the exact steps you've already executed: creating three Ubuntu 22.04 cloud-image based VMs (controller, compute, storage) on a single KVM host using DHCP reservations (via libvirt `net-update`) for stable IPs 192.168.122.10 / .11 / .12. All VMs currently have 4GB RAM, 2 vCPUs, 40G QCOW2 disks (backed by a common base image) and cloud-init user-data with your SSH key, timezone, and basic packages. Next you'll plug these into Ansible and finish the OpenStack deployment (Yoga) using the included playbooks.

## What You Already Did (Recap)
```bash
egrep -c '(vmx|svm)' /proc/cpuinfo               # Verified hardware virtualization
sudo apt update && sudo apt upgrade -y          # Updated host
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  bridge-utils virt-manager cloud-image-utils   # Installed virtualization stack
sudo usermod -aG libvirt,kvm $(whoami)          # Added user to libvirt/kvm groups
sudo virsh net-list --all                       # Ensured default network exists
sudo virsh net-start default                    # (If needed)
sudo virsh net-autostart default                # Autostart network

cd /var/lib/libvirt/images
sudo wget -O jammy-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
sudo chmod 644 jammy-server-cloudimg-amd64.img

# Added static DHCP reservations (MAC → Name/IP)
sudo virsh net-update default add ip-dhcp-host "<host mac='52:54:00:00:00:10' name='controller' ip='192.168.122.10'/>" --live --config
sudo virsh net-update default add ip-dhcp-host "<host mac='52:54:00:00:00:11' name='compute'    ip='192.168.122.11'/>" --live --config
sudo virsh net-update default add ip-dhcp-host "<host mac='52:54:00:00:00:12' name='storage'    ip='192.168.122.12'/>" --live --config

# Generated/confirmed SSH key and built cloud-init user-data files
[ -f ~/.ssh/id_rsa.pub ] || ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
PUBKEY="$(cat ~/.ssh/id_rsa.pub)"

for node in controller compute storage; do
  sudo tee ${node}-user-data.yaml > /dev/null <<EOF
#cloud-config
hostname: ${node}
manage_etc_hosts: true

users:
  - name: ubuntu
    ssh_authorized_keys:
      - ${PUBKEY}
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL

package_update: true
packages:
  - qemu-guest-agent
  - python3
  - python3-apt
  - git
  - net-tools
  - chrony

runcmd:
  - systemctl enable --now qemu-guest-agent
  - timedatectl set-timezone Africa/Tunis
EOF
done

sudo qemu-img create -f qcow2 -F qcow2 -b jammy-server-cloudimg-amd64.img controller.qcow2 40G
sudo qemu-img create -f qcow2 -F qcow2 -b jammy-server-cloudimg-amd64.img compute.qcow2   40G
sudo qemu-img create -f qcow2 -F qcow2 -b jammy-server-cloudimg-amd64.img storage.qcow2   40G

# Created the three VMs (4GB RAM, 2 vCPUs each)
sudo virt-install --name controller --ram 4096 --vcpus 2 \
  --disk path=/var/lib/libvirt/images/controller.qcow2,format=qcow2,bus=virtio \
  --os-variant ubuntu22.04 --virt-type kvm --graphics none \
  --network network=default,model=virtio,mac=52:54:00:00:00:10 \
  --import --cloud-init user-data=/var/lib/libvirt/images/controller-user-data.yaml

sudo virt-install --name compute --ram 4096 --vcpus 2 \
  --disk path=/var/lib/libvirt/images/compute.qcow2,format=qcow2,bus=virtio \
  --os-variant ubuntu22.04 --virt-type kvm --graphics none \
  --network network=default,model=virtio,mac=52:54:00:00:00:11 \
  --import --cloud-init user-data=/var/lib/libvirt/images/compute-user-data.yaml

sudo virt-install --name storage --ram 4096 --vcpus 2 \
  --disk path=/var/lib/libvirt/images/storage.qcow2,format=qcow2,bus=virtio \
  --os-variant ubuntu22.04 --virt-type kvm --graphics none \
  --network network=default,model=virtio,mac=52:54:00:00:00:12 \
  --import --cloud-init user-data=/var/lib/libvirt/images/storage-user-data.yaml
```

## What to Do Next
1. Verify the VMs are up and have the expected IPs.
2. Attach an additional disk for Cinder (storage node) so LVM has a dedicated volume.
3. Prepare/adjust Ansible inventory & group vars (already updated in repo to 192.168.122.10/11/12).
4. Confirm interface names inside each VM and set `management_interface` / `provider_interface` accordingly (default currently `enp1s0` or `ens3` depending on image/hypervisor). Update `group_vars/all.yml` if they differ.
5. Run Ansible ping test, then execute the playbook.
6. Post-deploy: source credentials and validate core OpenStack services.

---
## Step 1: Verify VMs & Connectivity
```bash
virsh list --all
virsh domifaddr controller
virsh domifaddr compute
virsh domifaddr storage

# SSH test (key-based auth)
ssh ubuntu@192.168.122.10 'hostname && uptime'
ssh ubuntu@192.168.122.11 'hostname && uptime'
ssh ubuntu@192.168.122.12 'hostname && uptime'

# Inside each VM (optional):
ip -o link show | awk -F': ' '{print NR, $2}'
ip -4 addr show
systemctl status qemu-guest-agent --no-pager
```

If interface name is not `enp1s0`, note the actual (e.g. `ens3`) and update `management_interface` / `provider_interface` in `group_vars/all.yml`.

## Step 2: Add a Dedicated Cinder Volume Disk
You only created one disk per VM. For Cinder LVM backend we need a second (empty) disk attached to the storage node.

```bash
# Create a new qcow2 disk (20G example)
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/cinder-volumes.qcow2 20G

# Attach it persistently as vdb (virtio)
sudo virsh attach-disk storage /var/lib/libvirt/images/cinder-volumes.qcow2 vdb \
  --persistent --subdriver=qcow2 --targetbus=virtio

# Inside storage VM (after it sees /dev/vdb):
ssh ubuntu@192.168.122.12 <<'EOF'
sudo lsblk
sudo pvcreate /dev/vdb
sudo vgcreate cinder-volumes /dev/vdb
sudo vgs
EOF
```

The repo `group_vars/storage.yml` now expects `volume_device: "/dev/vdb"` (updated). If your device path differs, adjust that variable.

## Step 3: Install Ansible & Clone Repo (Host Machine)
```bash
sudo apt update
sudo apt install -y ansible git python3-venv
git clone https://github.com/Akrem-Alamine/openstack-simple.git
cd openstack-simple
```

Inventory (`inventory/hosts`) and `group_vars/all.yml` are already aligned with:
```
controller 192.168.122.10
compute    192.168.122.11
storage    192.168.122.12
```

If you changed anything (IPs/MACs), regenerate the inventory accordingly.

## Step 4: Test Ansible Connectivity
```bash
ansible all -m ping
```
Expected result: `pong` from all three. If permission denied, ensure the same SSH key you inserted via cloud-init is `~/.ssh/id_rsa` (or set `ansible_ssh_private_key_file` host var).

## Step 5: Run OpenStack Deployment
```bash
ansible-playbook playbooks/site.yml
```

Monitor for failures. Common early failure points:
* Database service bind issues (verify controller IP reachable)
* Missing `cinder-volumes` VG (ensure Step 2 completed)
* Wrong interface name (adjust interfaces if Neutron/Linuxbridge tasks fail)

## Step 6: Post-Deployment Validation
On controller:
```bash
ssh ubuntu@192.168.122.10
sudo -i
source /root/admin-openrc  # (playbook should generate this)
openstack service list
openstack compute service list
openstack network agent list
openstack volume service list
```

Create a test network & flavor (optional quick smoke):
```bash
openstack flavor create --id auto --ram 512 --disk 5 --vcpus 1 m1.tiny
openstack network create demo-net
openstack subnet create --network demo-net --subnet-range 10.10.10.0/24 demo-subnet
```

## Horizon Access (If Deployed)
Forward the dashboard (assuming Apache on controller listens on port 80):
```bash
ssh -L 8080:192.168.122.10:80 <your_host_user>@<HOST_PUBLIC_IP>
# Then browse http://localhost:8080/horizon
```
Credentials: `admin / openstack123` (per `group_vars/all.yml`).

## Troubleshooting Quick Tips
| Issue | Check |
|-------|-------|
| VM missing IP | `virsh domifaddr <name>`; ensure MAC matches DHCP reservation |
| SSH fails | Permissions on `~/.ssh/id_rsa` (chmod 600); confirm key in `~/.ssh/authorized_keys` inside VM |
| Ansible cannot reach host | Add `-vvv` to see auth method; verify inventory IPs |
| Cinder fails LVM | `lsblk` on storage; ensure `/dev/vdb` exists & `vgs` shows `cinder-volumes` |
| Neutron agent down | Interface variable mismatch; run `ip -o link` in VMs & update `group_vars/all.yml` |
| Nova compute service down | Verify virtualization: inside compute `egrep -c '(vmx|svm)' /proc/cpuinfo` > 0 |

## Summary of Changes vs Earlier Guide
* Fixed static IPs via libvirt DHCP host entries (no manual static config in cloud-init).
* Uniform VM sizing: 4GB RAM / 2 vCPUs / 40G base disks (copy-on-write backing file usage).
* Added timezone & chrony sync in cloud-init.
* Using key-based SSH only (no plaintext passwords in YAML).
* Explicit additional disk step for Cinder separated from root disk.

Proceed now with Steps 1–5 if not already done; then validate services.

---
## Next Optional Enhancements
* Add provider (external) network using a Linux bridge on the host.
* Enable floating IP / external access by mapping a second libvirt network.
* Automate disk creation & VG setup via an Ansible pre-task.

Let me know if you want scripts for any of those.

## Installation Steps

### Step 1: Prepare for Ansible
```bash
# Install Ansible on GCP host
sudo apt install -y ansible git

# Clone repository
git clone https://github.com/Akrem-Alamine/openstack-simple.git
cd openstack-simple
```

### Step 2: Update Configuration
```bash
# Get VM IPs
CONTROLLER_IP=$(virsh domifaddr controller | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)
STORAGE_IP=$(virsh domifaddr storage | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)
COMPUTE_IP=$(virsh domifaddr compute | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)

echo "Controller: $CONTROLLER_IP"
echo "Storage: $STORAGE_IP"  
echo "Compute: $COMPUTE_IP"

# Update inventory
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

# Update variables
cat > group_vars/all.yml << EOF
# OpenStack configuration
openstack_release: "yoga"
admin_password: "openstack123"
database_password: "db_pass123"

# Node IPs
controller_ip: "$CONTROLLER_IP"
storage_ip: "$STORAGE_IP"
compute_ip: "$COMPUTE_IP"

# Network interface (usually first interface)
management_interface: "enp1s0"
provider_interface: "enp1s0"

# Database and messaging
transport_url: "rabbit://openstack:rabbit_pass123@$CONTROLLER_IP:5672/"
auth_url: "http://$CONTROLLER_IP:5000/v3"
EOF
```

### Step 3: Test Connectivity
```bash
# Test Ansible connection
ansible all -i inventory/hosts -m ping
```

### Step 4: Deploy OpenStack
```bash
# Run deployment
ansible-playbook -i inventory/hosts playbooks/site.yml
```

## Post-Installation

### Access Horizon Dashboard
```bash
# Get controller IP
CONTROLLER_IP=$(virsh domifaddr controller | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)

# From your local machine, create SSH tunnel:
ssh -L 8080:$CONTROLLER_IP:80 username@YOUR-GCP-VM-EXTERNAL-IP

# Then open: http://localhost:8080/horizon
# Login: admin / openstack123
```

### CLI Access
```bash
# SSH to controller
ssh ubuntu@$CONTROLLER_IP
# Password: ubuntu123

# Test OpenStack
source /root/admin-openrc
openstack service list
```

## Troubleshooting

### Common Issues
1. **VMs not accessible**: Wait 5 minutes for cloud-init to complete
2. **SSH fails**: Use password `ubuntu123` 
3. **No IP assigned**: Restart VM: `virsh shutdown VM_NAME && virsh start VM_NAME`

### Quick Commands
```bash
# VM management
virsh list --all                    # List VMs
virsh domifaddr controller          # Get VM IP
virsh console controller            # Connect to console
virsh shutdown controller           # Shutdown VM

# OpenStack services
systemctl status keystone           # Check service
journalctl -u keystone -f          # View logs
```

## Summary

This simplified setup gives you:
- **24GB GCP VM** running 3 internal VMs (6+4+8 = 18GB used, 6GB free)
- **200GB storage** with optimized disk allocation (50+30+60 = 140GB used)
- **Simple passwords** (ubuntu123 for VMs, openstack123 for admin)
- **Direct IP access** via DHCP (no complex networking)
- **Password authentication** (no SSH key management)
- **Quick deployment** with single script

## Key Simplifications Made

### Resource Optimization for 24GB Host
- **Controller VM**: Increased to 6GB RAM, 3 vCPUs, 50GB disk
- **Storage VM**: 4GB RAM, 2 vCPUs, 30GB disk  
- **Compute VM**: Increased to 8GB RAM, 4 vCPUs, 60GB disk
- **Total**: 18GB RAM used (6GB free for host OS)

### Password Simplification
- **VM Password**: Plain text `ubuntu123` in cloud-init
- **SSH**: Password authentication enabled
- **No encrypted hashes** or complex SSH key management
- **Single password** for all VMs

### Configuration Simplification
- **Auto IP discovery**: Script automatically finds VM IPs
- **Pre-configured inventory**: No manual IP entry needed
- **Simplified ansible.cfg**: Password auth instead of SSH keys
- **One-command deployment**: `./quick-setup.sh` does everything

### Cloud-Init Simplification
- **Minimal packages**: Only essential packages installed
- **Plain text passwords**: No complex password hashing
- **Simple user config**: Just ubuntu user with sudo access
- **Removed complex networking**: Uses DHCP instead of static IPs

**Total setup time**: ~30 minutes  
**Access**: SSH tunnel for Horizon dashboard  
**Maintenance**: Simple `virsh` commands for VM management