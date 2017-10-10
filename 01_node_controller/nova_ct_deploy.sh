#!/bin/bash

source ../briefcase

## NOVA ##
# NOVA DB CONFIG #

echo "Create NOVA DB"

mysql -uroot -p${ROOT_DBPASS} -e "CREATE DATABASE nova;"
mysql -uroot -p${ROOT_DBPASS} -e "CREATE DATABASE nova_api;"
mysql -uroot -p${ROOT_DBPASS} -e "CREATE DATABASE nova_cell0;"

mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '${NOVA_DBPASS}';"
mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '${NOVA_DBPASS}';"

mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${NOVA_DBPASS}';"
mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '${NOVA_DBPASS}';"

mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '${NOVA_DBPASS}';"
mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '${NOVA_DBPASS}';"

# NOVA service credential #
echo "Create NOVA service credential"
. ~/admin-openrc

openstack user create --domain default --password $NOVA_PASS nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://$CTHOST:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://$CTHOST:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://$CTHOST:8774/v2.1

openstack user create --domain default --password $PLACEMENT_PASS placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://$CTHOST:8778
openstack endpoint create --region RegionOne placement internal http://$CTHOST:8778
openstack endpoint create --region RegionOne placement admin http://$CTHOST:8778

firewall-cmd --zone=public --add-port=8774/tcp --permanent
firewall-cmd --zone=public --add-port=8778/tcp --permanent
firewall-cmd --zone=public --add-port=6080/tcp --permanent
firewall-cmd --reload

yum install -y openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api

mv /etc/nova/nova.conf /etc/nova/nova.conf.orig

cat << EOF > /etc/nova/nova.conf
[DEFAULT]
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:$RABBIT_PASS@$CTHOST
my_ip = $ETH0IP
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver
verbose = true

block_device_allocate_retries = 600
block_device_allocate_retries_interval = 10
block_device_creation_timeout = 600

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
ovs_bridge = $BR_INT

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

[scheduler]
discover_hosts_in_cells_interval = 300

[vnc]
#enabled = true
#vncserver_listen =
#vncserver_proxyclient_address =
EOF

chown root:nova /etc/nova/nova.conf

mv /etc/httpd/conf.d/00-nova-placement-api.conf /etc/httpd/conf.d/00-nova-placement-api.conf.orig

cp ./configfile/00-nova-placement-api.conf /etc/httpd/conf.d/00-nova-placement-api.conf

systemctl restart httpd
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
nova-manage cell_v2 list_cells

systemctl enable openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service

. ~/admin-openrc
openstack compute service list
