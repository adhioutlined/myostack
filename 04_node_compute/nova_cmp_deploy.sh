#!/bin/bash

source ../briefcase

## Install pip ##
yum -y install python-pip
pip install --upgrade pip
pip install os-xenapi xenapi

## install Nova-Package ##
yum install -y openstack-nova-compute sysfsutils

mv /etc/nova/nova.conf /etc/nova/nova.conf.orig

cat << EOF > /etc/nova/nova.conf
[DEFAULT]
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:$RABBIT_PASS@$CTHOST
my_ip = $ETH0IP
# use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver
verbose = true
compute_driver = xenapi.XenAPIDriver
block_device_allocate_retries = 600
block_device_allocate_retries_interval = 10
block_device_creation_timeout = 600
volume_attach_retry_count = 20

[api]
auth_strategy = keystone

[api_database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@$CTHOST/nova_api

[cinder]
os_region_name = RegionOne

[database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@$CTHOST/nova

[glance]
api_servers = http://$CTHOST:9292

[keystone_authtoken]
auth_uri = http://$CTHOST:5000
auth_url = http://$CTHOST:35357
memcached_servers = $CTHOST:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = $NOVA_PASS

[neutron]
url = http://$CTHOST:9696
auth_url = http://$CTHOST:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
region_name = RegionOne
project_name = service
username = neutron
password = $NEUTRON_PASS
service_metadata_proxy = True
metadata_proxy_shared_secret = $METADATA_SECRET
ovs_bridge = $XAPIBR

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[placement]
os_region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://$CTHOST:35357/v3
username = placement
password = $PLACEMENT_PASS

[vnc]
enabled = true
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = $XSIP
novncproxy_base_url = http://$CTHOST:6080/vnc_auto.html

[xenserver]
connection_url = http://$XSIP
connection_username = $XSUSER
connection_password = $XSPASSWORD
sr_matching_filter = "default-sr:true"
xenapi_image_upload_handler=nova.virt.xenapi.image.glance.GlanceStore
# vif_driver = nova.virt.xenapi.vif.XenAPIOpenVswitchDriver
ovs_int_bridge=$XAPIBR
ovs_integration_bridge=$XAPIBR
EOF

chown root:nova /etc/nova/nova.conf

mv /etc/lvm/lvm.conf /etc/lvm/lvm.conf.orig
cp ./configfile/lvm.conf /etc/lvm/lvm.conf

systemctl enable openstack-nova-compute.service
systemctl start openstack-nova-compute.service
