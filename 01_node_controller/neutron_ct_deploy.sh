#!/bin/bash

source ../briefcase
eth0ip=$(ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}')

## NEUTRON ##
# NEUTRON DB CONFIG #

echo "Create NEUTRON DB"

mysql -uroot -p${ROOT_DBPASS} -e "CREATE DATABASE neutron;"
mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '${NEUTRON_DBPASS}';"
mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '${NEUTRON_DBPASS}';"

. ~/admin-openrc
openstack user create --domain default --password $NEUTRON_PASS neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network

openstack endpoint create --region RegionOne network public http://$CTHOST:9696
openstack endpoint create --region RegionOne network internal http://$CTHOST:9696
openstack endpoint create --region RegionOne network admin http://$CTHOST:9696

firewall-cmd --zone=public --add-port=9696/tcp --permanent

yum install -y openstack-neutron openstack-neutron-ml2 python-neutronclient ebtables ipset

mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.orig
cat << EOF > /etc/neutron/neutron.conf
[DEFAULT]
verbose = true
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = true
transport_url = rabbit://openstack:$RABBIT_PASS@$CTHOST
auth_strategy = keystone

notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true

[database]
connection = mysql+pymysql://neutron:$NEUTRON_DBPASS@$CTHOST/neutron

[keystone_authtoken]
auth_uri = http://$CTHOST:5000
auth_url = http://$CTHOST:35357
memcached_servers = $CTHOST:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = $NEUTRON_PASS

[nova]
auth_url = http://$CTHOST:35357
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = $NOVA_PASS

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
EOF

chown root:neutron /etc/neutron/neutron.conf

mv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.orig

cat << EOF > /etc/neutron/plugins/ml2/ml2_conf.ini
[ml2]
type_drivers = flat,vlan
tenant_network_types = vlan
mechanism_drivers = openvswitch
extension_drivers = port_security

[ml2_type_flat]
flat_networks = *

[ml2_type_vlan]
network_vlan_ranges = $VNETNAME:$VNETMIN:$VNETMAX

[securitygroup]
enable_security_group = True
enable_ipset = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
EOF

chown root:neutron /etc/neutron/plugins/ml2/ml2_conf.ini


ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron


systemctl restart openstack-nova-api.service
systemctl enable neutron-server.service
systemctl start neutron-server.service
