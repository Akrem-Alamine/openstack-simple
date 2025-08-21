#!/bin/bash

# OpenStack Validation Script
# This script validates the OpenStack deployment

echo "========================================"
echo "OpenStack Deployment Validation"
echo "========================================"

# Source admin credentials
if [ -f /root/admin-openrc ]; then
    source /root/admin-openrc
else
    echo "ERROR: Admin credentials file not found!"
    exit 1
fi

echo "Testing OpenStack services..."

# Test service connectivity
echo "1. Testing Keystone..."
if openstack token issue > /dev/null 2>&1; then
    echo "   ✓ Keystone is working"
else
    echo "   ✗ Keystone failed"
fi

echo "2. Testing Glance..."
if openstack image list > /dev/null 2>&1; then
    echo "   ✓ Glance is working"
    echo "   Images available: $(openstack image list -f value -c Name | wc -l)"
else
    echo "   ✗ Glance failed"
fi

echo "3. Testing Nova..."
if openstack compute service list > /dev/null 2>&1; then
    echo "   ✓ Nova is working"
    echo "   Compute services: $(openstack compute service list -f value | wc -l)"
else
    echo "   ✗ Nova failed"
fi

echo "4. Testing Neutron..."
if openstack network agent list > /dev/null 2>&1; then
    echo "   ✓ Neutron is working"
    echo "   Network agents: $(openstack network agent list -f value | wc -l)"
else
    echo "   ✗ Neutron failed"
fi

echo "5. Testing Cinder..."
if openstack volume service list > /dev/null 2>&1; then
    echo "   ✓ Cinder is working"
    echo "   Volume services: $(openstack volume service list -f value | wc -l)"
else
    echo "   ✗ Cinder failed"
fi

echo "6. Testing Horizon..."
if curl -s -o /dev/null -w "%{http_code}" http://$(hostname -I | awk '{print $1}')/horizon | grep -q "200\|302"; then
    echo "   ✓ Horizon is accessible"
else
    echo "   ✗ Horizon not accessible"
fi

echo ""
echo "Service Status Summary:"
echo "======================="
openstack service list

echo ""
echo "Endpoint Summary:"
echo "================="
openstack endpoint list

echo ""
echo "Compute Service Status:"
echo "======================="
openstack compute service list

echo ""
echo "Network Agent Status:"
echo "===================="
openstack network agent list

echo ""
echo "Volume Service Status:"
echo "====================="
openstack volume service list

echo ""
echo "Available Resources:"
echo "==================="
echo "Flavors:"
openstack flavor list

echo ""
echo "Images:"
openstack image list

echo ""
echo "========================================"
echo "Validation completed!"
echo ""
echo "Access Horizon at: http://$(hostname -I | awk '{print $1}')/horizon"
echo "Username: admin"
echo "Password: Check group_vars/all.yml"
echo "========================================"
