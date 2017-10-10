#!/bin/bash

source ../briefcase
eth0ip=$(ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}')

## NEUTRON ##
# NEUTRON DB CONFIG #


firewall-cmd --zone=public --add-port=9696/tcp --permanent
firewall-cmd --reload

yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch python-neutronclient ebtables ipset

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

mv /etc/neutron/plugins/ml2/openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini.orig

cat << EOF > /etc/neutron/plugins/ml2/openvswitch_agent.ini
[ovs]
integration_bridge = $BR_INT
bridge_mappings = $VNETNAME:$BR_VNET
# of_interface = ovs-ofctl
# ovsdb_interface = vsctl

[securitygroup]
enable_security_group = True
enable_ipset = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
EOF

chown root:neutron /etc/neutron/plugins/ml2/openvswitch_agent.ini

mv /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.orig

cat << EOF > /etc/neutron/dhcp_agent.ini
[DEFAULT]
verbose = true
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
ovs_integration_bridge = $BR_INT
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata= True
EOF
chown root:neutron /etc/neutron/dhcp_agent.ini

mv /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.orig

cat << EOF > /etc/neutron/metadata_agent.ini
[DEFAULT]
verbose = true
auth_uri = http://$CTHOST:5000
auth_url = http://$CTHOST:35357
auth_region = RegionOne
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $NEUTRON_PASS
nova_metadata_ip = $CTIP
metadata_proxy_shared_secret = $METADATA_SECRET
EOF

chown root:neutron /etc/neutron/metadata_agent.ini

mv /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.orig

cat << EOF > /etc/neutron/l3_agent.ini
[DEFAULT]
verbose = true
interface_driver = openvswitch
ovs_integration_bridge = $BR_INT
enable_metadata_proxy = true

[agent]
comment_iptables_rules = True
[ovs]
EOF

chown root:neutron /etc/neutron/l3_agent.ini

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

systemctl enable openvswitch.service
systemctl start openvswitch.service

ovs-vsctl add-br $BR_VNET
ovs-vsctl add-port $BR_VNET $IFTOVLANBR

systemctl enable neutron-openvswitch-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service neutron-l3-agent.service
systemctl start neutron-openvswitch-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service neutron-l3-agent.service
