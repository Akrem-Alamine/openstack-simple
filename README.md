# Simple OpenStack Setup with Custom Ansible Playbooks

[![OpenStack](https://img.shields.io/badge/OpenStack-Yoga-red.svg)](https://docs.openstack.org/yoga/)
[![Ansible](https://img.shields.io/badge/Ansible-4.0+-blue.svg)](https://ansible.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04-orange.svg)](https://ubuntu.com/)

## 🚀 Overview
This is a **simplified OpenStack deployment** for learning and testing purposes using custom Ansible playbooks. Perfect for developers and students who want to understand OpenStack without the complexity of production deployments.

### 🏗️ Architecture
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Controller  │    │   Storage   │    │   Compute   │
│             │    │             │    │             │
│ • Keystone  │    │ • Cinder    │    │ • Nova      │
│ • Glance    │    │ • LVM       │    │ • Neutron   │
│ • Nova API  │    │ • iSCSI     │    │ • libvirt   │
│ • Neutron   │    │             │    │             │
│ • Horizon   │    │             │    │             │
│ • MySQL     │    │             │    │             │
│ • RabbitMQ  │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
```

## ✨ Features
- 🎯 **Simple & Clean**: No complex OpenStack-Ansible overhead
- 📚 **Educational**: Easy to understand each component
- 🔧 **Modular**: Each service in separate playbook
- 🎨 **Customizable**: Easy to modify for your needs
- ✅ **Reliable**: Tested deployment sequence
- 🧹 **Manageable**: Clear cleanup and validation scripts

## 📋 Prerequisites
- **3 VMs** (Ubuntu 20.04 LTS recommended)
- **Resources**: 4GB RAM, 20GB disk per VM
- **Network**: All VMs connected with SSH access
- **Virtualization**: KVM, VirtualBox, or Docker
- **Host**: GCP VM or local machine

## 🛠️ What Gets Installed
| Node | Services |
|------|----------|
| **Controller** | Keystone, Glance, Nova API, Neutron Server, Horizon, MySQL, RabbitMQ |
| **Storage** | Cinder Volume, LVM, iSCSI |
| **Compute** | Nova Compute, Neutron Agent, libvirt |

## 📁 Directory Structure
```
openstack-simple/
├── 📄 README.md                          # This file
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
│   ├── 01-database.yml                  # MySQL & RabbitMQ
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
