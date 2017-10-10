#!/bin/bash

source ../briefcase
eth0ip=$(ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}')


## KEYSTONE ##
# KEYSTONE DB CONFIG #
echo "INSTALL KEYSTONE & KEYSTONE DB CONFIG"

mysql -uroot -p${ROOT_DBPASS} -e "CREATE DATABASE keystone;"
mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '${KEYSTONE_DBPASS}';"
mysql -uroot -p${ROOT_DBPASS} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '${KEYSTONE_DBPASS}';"

yum install -y openstack-keystone mod_wsgi
mv /etc/keystone/keystone.conf /etc/keystone/keystone.conf.orig

cat << EOF > /etc/keystone/keystone.conf
[DEFAULT]
[assignment]
[auth]
[cache]
[catalog]
[cors]
[cors.subdomain]
[credential]
[database]
connection = mysql+pymysql://keystone:$KEYSTONE_DBPASS@$CTHOST/keystone
[domain_config]
[endpoint_filter]
[endpoint_policy]
[eventlet_server]
[federation]
[fernet_tokens]
[healthcheck]
[identity]
[identity_mapping]
[kvs]
[ldap]
[matchmaker_redis]
[memcache]
[oauth1]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[paste_deploy]
[policy]
[profiler]
[resource]
[revoke]
[role]
[saml]
[security_compliance]
[shadow_users]
[signing]
[token]
provider = fernet
[tokenless_auth]
[trust]
EOF

chown root:keystone /etc/keystone/keystone.conf
su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
  --bootstrap-admin-url http://$CTHOST:35357/v3/ \
  --bootstrap-internal-url http://$CTHOST:5000/v3/ \
  --bootstrap-public-url http://$CTHOST:5000/v3/ \
  --bootstrap-region-id RegionOne

sudo sed -i -e 's/'"#ServerName www.example.com:80"'/'"ServerName $CTHOST"'/g' /etc/httpd/conf/httpd.conf

ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/

systemctl restart httpd.service

firewall-cmd --zone=public --add-port=35357/tcp --permanent
firewall-cmd --zone=public --add-port=5000/tcp --permanent
firewall-cmd --reload
firewall-cmd --list-ports

## Service Entity & API Endpoints ##
echo "KEYSTONE Service Entity & API Endpoints"

export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://$CTHOST:35357/v3
export OS_IDENTITY_API_VERSION=3

### Domain, projects, users, roles ###
echo "KEYSTONE Create Domain, projects, users, roles "

openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password $DEMO_PASS demo
openstack role create user
openstack role add --project demo --user demo user

sed -i -e 's/'"request_id admin_token_auth build_auth_context"'/'"request_id build_auth_context"'/g' /etc/keystone/keystone-paste.ini

unset OS_AUTH_URL OS_PASSWORD

openstack --os-auth-url http://$CTHOST:35357/v3 --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password $ADMIN_PASS token issue
openstack --os-auth-url http://$CTHOST:5000/v3 --os-project-domain-name default --os-user-domain-name default --os-project-name demo --os-username demo --os-password $DEMO_PASS token issue

cat << EOF > ~/admin-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$CTHOST:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

cat << EOF > ~/demo-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=DEMO_PASS
export OS_AUTH_URL=http://$CTHOST:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

### FINALIZE ###
echo "KEYSTONE FINALIZE"

. ~/admin-openrc

openstack token issue
