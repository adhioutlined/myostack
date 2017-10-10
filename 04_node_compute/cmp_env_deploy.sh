#!/bin/bash

source ../briefcase
## install NTP via chrony ##
yum install -y chrony
systemctl enable chronyd.service

sed -i '/centos/d' /etc/chrony.conf
cat "server $CTHOST iburst" > /etc/hosts
systemctl start chronyd.service


## install support package ##
yum install -y epel-release
yum makecache fast
yum install -y git htop tmux telnet bash-completion bash-completion-extras wget
yum remove -y epel-release

## Enable openstack-repo ##
yum install -y centos-release-openstack-ocata
yum upgrade -y
yum install -y python-openstackclient openstack-selinux

## NEtWOrk Section ##
systemctl stop NetworkManager.service
systemctl disable NetworkManager.service
systemctl enable network.service
systemctl start network.service
mv /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0.orig

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE="eth0"
BOOTPROTO="static"
ONBOOT="yes"
TYPE="Ethernet"
IPADDR=$CMPIP
NETMASK=$CMPNETMASK
GATEWAY=$CMPGATEWAY
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE="eth1"
BOOTPROTO="none"
ONBOOT="yes"
TYPE="Ethernet"
EOF

mv  /etc/resolv.conf  /etc/resolv.conf.orig
cat << EOF > /etc/resolv.conf
nameserver $NAMESERVER1
nameserver $NAMESERVER2
EOF

hostnamectl set-hostname $CMPHOST

echo "$CTIP $CTHOST" >> /etc/hosts
echo "$NETIP $NETHOST" >> /etc/hosts
echo "$CMPIP $CMPHOST" >> /etc/hosts
echo "$CMP2IP $CMP2HOST" >> /etc/hosts

## Setup HIMN Interface ##
domid=$(xenstore-read domid)
mac=$(xenstore-read /local/domain/$domid/vm-data/himn_mac)
dev_path=$(grep -l $mac /sys/class/net/*/address)
dev=$(basename $(dirname $dev_path))
ifcfg_file="/etc/sysconfig/network-scripts/ifcfg-$dev"

touch $ifcfg_file
echo "DEVICE=$dev" >> $ifcfg_file
echo "BOOTPROTO=dhcp" >> $ifcfg_file
echo "ONBOOT=yes" >> $ifcfg_file
echo "TYPE=Ethernet" >> $ifcfg_file
echo "METRIC=101" >> $ifcfg_file
ifup $dev


## reboot after upgrade ##
reboot
