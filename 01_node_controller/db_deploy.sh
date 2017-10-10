#!/bin/bash

source ../briefcase

## install DB package ##
yum install -y mariadb mariadb-server python2-PyMySQL

## create openstack DB config file ##
cat << EOF > /etc/my.cnf.d/openstack.cnf
[mysqld]
bind-address = $ETH0IP
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF

systemctl enable mariadb.service
systemctl start mariadb.service

## mysql_secure_installation ##
mysql -uroot -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${ROOT_DBPASS}');"
mysql -uroot -p${ROOT_DBPASS} -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -uroot -p${ROOT_DBPASS} -e "DELETE FROM mysql.user WHERE User='';"
mysql -uroot -p${ROOT_DBPASS} -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
mysql -uroot -p${ROOT_DBPASS} -e "FLUSH PRIVILEGES;"

## rabbitmq install ##
yum install -y rabbitmq-server
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

firewall-cmd --zone=public --add-port=11211/tcp --permanent
firewall-cmd --zone=public --add-port=5672/tcp --permanent
firewall-cmd --reload

## memcached installed ##
yum install -y memcached python-memcached
sed -i -e 's/'"-l 127.0.0.1,::1"'/'"-l 127.0.0.1,::1,$CTHOST"'/g'  /etc/sysconfig/memcached
systemctl enable memcached.service
systemctl start memcached.service

## install phpmyadmin ##
yum -y install httpd php php-mysql php-gd php-pear php-mbstring

yum -y install epel-release
yum makecache fast
yum -y install phpmyadmin
yum -y remove epel-release

mv /etc/httpd/conf.d/phpMyAdmin.conf /etc/httpd/conf.d/phpMyAdmin.conf.orig

cp ./configfile/phpMyAdmin.conf /etc/httpd/conf.d/phpMyAdmin.conf

firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --reload

systemctl enable httpd.service
systemctl start httpd.service
