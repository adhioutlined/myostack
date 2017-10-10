#!/bin/bash

source ../briefcase
## install NTP via chrony ##
yum install -y chrony
systemctl enable chronyd.service
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
IPADDR=$CTIP
NETMASK=$CTNETMASK
GATEWAY=$CTGATEWAY
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

hostnamectl set-hostname $CTHOST

echo "$CTIP $CTHOST" >> /etc/hosts
echo "$NETIP $NETHOST" >> /etc/hosts
echo "$CMPIP $CMPHOST" >> /etc/hosts
echo "$CMP2IP $CMP2HOST" >> /etc/hosts



## reboot after upgrade ##
reboot
