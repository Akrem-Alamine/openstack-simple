# Simple OpenStack Setup

[![OpenStack](https://img.shields.io/badge/OpenStack-Yoga-red.svg)](https://docs.openstack.org/yoga/)
[![Ansible](https://img.shields.io/badge/Ansible-4.0+-blue.svg)](https://ansible.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange.svg)](https://ubuntu.com/)

## 🚀 Overview
**Simplified OpenStack deployment** for GCP VM with 24GB RAM and 200GB storage. Perfect for learning and testing OpenStack without production complexity.

### 🏗️ Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                GCP VM Host (24GB RAM, 200GB)               │
│                  (Ubuntu 22.04 LTS)                        │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Controller  │  │   Storage   │  │   Compute   │         │
│  │  6GB RAM    │  │  4GB RAM    │  │  8GB RAM    │         │
│  │  3 vCPUs    │  │  2 vCPUs    │  │  4 vCPUs    │         │
│  │  50GB disk  │  │  30GB disk  │  │  60GB disk  │         │
│  │             │  │             │  │             │         │
│  │ • Keystone  │  │ • Cinder    │  │ • Nova      │         │
│  │ • Glance    │  │ • LVM       │  │ • Neutron   │         │
│  │ • Nova API  │  │ • iSCSI     │  │ • libvirt   │         │
│  │ • Neutron   │  │             │  │             │         │
│  │ • Horizon   │  │             │  │             │         │
│  │ • PostgreSQL│  │             │  │             │         │
│  │ • RabbitMQ  │  │             │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## ✨ Features
- 🎯 **Simple**: No complex configurations
- 📚 **Educational**: Easy to understand
- 🔧 **Optimized**: Perfect for 24GB GCP VM
- 🎨 **Clean**: Plain text passwords
- ✅ **Fast**: ~30 minute setup
- 🧹 **Manageable**: Clear scripts

## 📋 Quick Start

### Option 1: Automated Setup
```bash
# On your GCP VM (Ubuntu 22.04)
wget -O - https://raw.githubusercontent.com/Akrem-Alamine/openstack-simple/main/quick-setup.sh | bash
```

### Option 2: Manual Setup
```bash
# 1. Create GCP VM with nested virtualization
gcloud compute instances create openstack-host \
  --zone=us-east1-c \
  --machine-type=n1-standard-8 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=200GB \
  --enable-nested-virtualization \
  --tags=http-server,https-server

# 2. SSH to GCP VM and run setup
ssh username@YOUR-GCP-VM-IP
git clone https://github.com/Akrem-Alamine/openstack-simple.git
cd openstack-simple
./quick-setup.sh

# 3. Deploy OpenStack
./scripts/deploy.sh
```

## 🛠️ What Gets Installed
| Node | RAM | vCPUs | Disk | Services |
|------|-----|-------|------|----------|
| **Controller** | 6GB | 3 | 50GB | Keystone, Glance, Nova API, Neutron, Horizon, PostgreSQL, RabbitMQ |
| **Storage** | 4GB | 2 | 30GB | Cinder Volume, LVM, iSCSI |
| **Compute** | 8GB | 4 | 60GB | Nova Compute, Neutron Agent, libvirt |

## � Default Credentials
- **VM SSH**: ubuntu / ubuntu123
- **OpenStack Admin**: admin / openstack123
- **Database**: root / db_pass123

## 🌐 Access Dashboard
```bash
# Get controller IP
CONTROLLER_IP=$(virsh domifaddr controller | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)

# Create SSH tunnel from your local machine
ssh -L 8080:$CONTROLLER_IP:80 username@YOUR-GCP-VM-IP

# Open browser: http://localhost:8080/horizon
# Login: admin / openstack123
```
├── 📋 deployment-commands.md              # Detailed deployment guide
├── 🔧 ansible.cfg                        # Ansible configuration
├── 📂 inventory/
│   └── hosts                             # VM inventory
├── 📂 group_vars/                        # Configuration variables
│   ├── all.yml                          # Global settings
│   ├── controller.yml                   # Controller-specific
│   ├── storage.yml                      # Storage-specific
│   └── compute.yml                      # Compute-specific
├── 📂 playbooks/                        # Ansible playbooks
│   ├── site.yml                         # Main deployment
│   ├── 00-prerequisites.yml             # System preparation
│   ├── 01-database.yml                  # PostgreSQL & RabbitMQ
│   ├── 02-keystone.yml                  # Identity service
│   ├── 03-glance.yml                    # Image service
│   ├── 04-nova.yml                      # Compute service
│   ├── 05-neutron.yml                   # Networking
│   ├── 06-cinder.yml                    # Block storage
│   └── 07-horizon.yml                   # Web dashboard
└── 📂 scripts/
    ├── deploy.sh                        # One-click deployment
    ├── cleanup.sh                       # Clean removal
    ├── validate.sh                      # Test deployment
    └── quick-setup.sh                   # Guided setup
```

## 🚀 Quick Start

### 1️⃣ Clone Repository
```bash
git clone https://github.com/yourusername/openstack-simple.git
cd openstack-simple
```

### 2️⃣ Configure Your Environment
```bash
# Edit with your VM IPs
nano inventory/hosts
nano group_vars/all.yml
```

### 3️⃣ Deploy OpenStack
```bash
chmod +x scripts/*.sh
./scripts/quick-setup.sh  # Guided setup
# OR
./scripts/deploy.sh       # Direct deployment
```

### 4️⃣ Access Dashboard
- 🌐 **URL**: `http://your-controller-ip/horizon`
- 👤 **Username**: `admin`
- 🔑 **Password**: `openstack123`
- 🏠 **Domain**: `Default`

## 📖 Detailed Documentation
- 📋 [Deployment Commands](deployment-commands.md) - Step-by-step guide
- 📁 [File Transfer Guide](file-transfer-guide.md) - Getting files to your VMs

## ⏱️ Installation Timeline
| Phase | Duration |
|-------|----------|
| Prerequisites | 10-15 min |
| SSH Setup | 5-10 min |
| OpenStack Deployment | 30-45 min |
| Validation | 5 min |
| **Total** | **~1 hour** |

## 🎯 Success Indicators
- ✅ All VMs respond to ping
- ✅ SSH connectivity works
- ✅ Ansible can reach all nodes
- ✅ All services start successfully
- ✅ Horizon dashboard accessible
- ✅ Can create test instances

## 🔧 Troubleshooting
Common issues and solutions are documented in [deployment-commands.md](deployment-commands.md#troubleshooting-common-issues)

## 🤝 Contributing
This is a learning-focused project. Feel free to:
- Report issues
- Suggest improvements
- Add more services
- Share your experience

## 📄 License
MIT License - Feel free to use for learning and testing

## ⚠️ Important Notes
- This is **NOT for production use**
- Designed for **learning and testing**
- Uses **simplified security settings**
- **No high availability** features

## 🎓 Learning Resources
- [OpenStack Documentation](https://docs.openstack.org/)
- [Ansible Documentation](https://docs.ansible.com/)
- [OpenStack Architecture Guide](https://docs.openstack.org/arch-guide/)

---
**Made with ❤️ for OpenStack learners**
