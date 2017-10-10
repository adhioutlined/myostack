#!/bin/bash

source ../briefcase

yum install -y openstack-neutron openstack-neutron-openvswitch ebtables ipset openvswitch openstack-neutron-ml2

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
[DEFAULT]
verbose = True
ovs_integration_bridge = $XAPIBR


[ovs]
integration_bridge = $XAPIBR
bridge_mappings = $VNETNAME:$XSBROUT1
of_interface = ovs-ofctl
ovsdb_interface = vsctl

[agent]
root_helper = neutron-rootwrap-xen-dom0 /etc/neutron/rootwrap.conf
root_helper_daemon =
minimize_polling = False

[securitygroup]
enable_security_group = True
enable_ipset = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

[xenapi]
connection_url = http://$XSINTIP
connection_username = $XSUSER
connection_password = $XSPASSWORD
EOF

chown root:neutron /etc/neutron/plugins/ml2/openvswitch_agent.ini

sed -i -e 's#'"xenapi_connection_url=.*$"'#'"xenapi_connection_url=http://$XSINTIP"'#g'  /etc/neutron/rootwrap.conf
sed -i -e 's#'"xenapi_connection_password=.*$"'#'"xenapi_connection_password=$XSPASSWORD"'#g'  /etc/neutron/rootwrap.conf

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

 systemctl enable neutron-openvswitch-agent.service
  systemctl start neutron-openvswitch-agent.service 
