#!/bin/bash

source ../briefcase
eth0ip=$(ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}')

## GLANCE ##
# GLANCE DB CONFIG #

echo "Create Glance DB"

mysql -uroot -p${ROOT_DBPASS} -e "CREATE DATABASE glance;"
mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${GLANCE_DBPASS}';"
mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '${GLANCE_DBPASS}';"


# GLANCE service credential #
echo "Create GLANCE service credential"
. ~/admin-openrc

openstack user create --domain default --password $GLANCE_PASS glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://$CTHOST:9292
openstack endpoint create --region RegionOne image internal http://$CTHOST:9292
openstack endpoint create --region RegionOne image admin http://$CTHOST:9292

firewall-cmd --zone=public --add-port=9292/tcp --permanent
firewall-cmd --reload

# Install Glance Service #
echo "Install Glance Service"

yum install -y openstack-glance python-glance python-glanceclient

# Config Glance Service #
echo "Config Glance Service"
mv /etc/glance/glance-api.conf /etc/glance/glance-api.conf.orig

cat << EOF > /etc/glance/glance-api.conf
[DEFAULT]
verbose = true
[cors]
[cors.subdomain]
[database]
connection = mysql+pymysql://glance:$GLANCE_DBPASS@$CTHOST/glance
[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images
[image_format]
[keystone_authtoken]
auth_uri = http://$CTHOST:5000
auth_url = http://$CTHOST:35357
memcached_servers = $CTHOST:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = glance
password = $GLANCE_PASS
[matchmaker_redis]
[oslo_concurrency]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[paste_deploy]
flavor = keystone
[profiler]
[store_type_location_strategy]
[task]
[taskflow_executor]
EOF

mv /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.orig
cat << EOF > /etc/glance/glance-registry.conf
[DEFAULT]
verbose = true
[database]
connection = mysql+pymysql://glance:$GLANCE_DBPASS@$CTHOST/glance
[keystone_authtoken]
auth_uri = http://$CTHOST:5000
auth_url = http://$CTHOST:35357
memcached_servers = $CTHOST:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = glance
password = $GLANCE_PASS
[matchmaker_redis]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_policy]
[paste_deploy]
flavor = keystone
[profiler]
EOF

chown root:glance /etc/glance/glance-api.conf
chown root:glance /etc/glance/glance-registry.conf

su -s /bin/sh -c "glance-manage db_sync" glance

systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service

# Upload Cirros Image #
echo "Upload Cirros Image"
. ~/admin-openrc
wget -O /tmp/cirros-0.3.5-x86_64-disk.vhd.tgz http://iso.idweb.host/cirros/cirros-0.3.5-x86_64-disk.vhd.tgz
openstack image create "cirros-xen" --file /tmp/cirros-0.3.5-x86_64-disk.vhd.tgz --disk-format vhd --container-format ovf --public
openstack image list

rm -rf /tmp/cirros-0.3.5-x86_64-disk.vhd.tgz
