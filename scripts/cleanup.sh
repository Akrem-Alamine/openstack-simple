#!/bin/bash

# Cleanup script for OpenStack deployment
# This script removes OpenStack services and data

set -e

echo "========================================"
echo "OpenStack Cleanup Starting..."
echo "========================================"

read -p "This will remove all OpenStack services and data. Are you sure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

echo "Stopping OpenStack services..."
ansible openstack -i inventory/hosts -b -m shell -a "systemctl stop apache2 postgresql rabbitmq-server glance-api nova-api nova-conductor nova-scheduler neutron-server cinder-volume nova-compute neutron-linuxbridge-agent || true"

echo "Removing OpenStack packages..."
ansible openstack -i inventory/hosts -b -m apt -a "name=keystone,glance,nova-api,nova-conductor,nova-scheduler,neutron-server,cinder-volume,nova-compute,neutron-linuxbridge-agent,horizon state=absent autoremove=yes"

echo "Removing databases (PostgreSQL)..."
ansible controller -i inventory/hosts -b -m shell -a "sudo -u postgres psql -c \"DROP DATABASE IF EXISTS keystone;\" -c \"DROP DATABASE IF EXISTS glance;\" -c \"DROP DATABASE IF EXISTS nova;\" -c \"DROP DATABASE IF EXISTS nova_api;\" -c \"DROP DATABASE IF EXISTS nova_cell0;\" -c \"DROP DATABASE IF EXISTS neutron;\" -c \"DROP DATABASE IF EXISTS cinder;\""

echo "Removing configuration files..."
ansible openstack -i inventory/hosts -b -m shell -a "rm -rf /etc/keystone /etc/glance /etc/nova /etc/neutron /etc/cinder /etc/openstack-dashboard"

echo "Removing data directories..."
ansible openstack -i inventory/hosts -b -m shell -a "rm -rf /var/lib/keystone /var/lib/glance /var/lib/nova /var/lib/neutron /var/lib/cinder"

echo "Cleanup completed!"
