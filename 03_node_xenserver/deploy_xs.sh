#!/bin/sh

source ../briefcase



echo "$CTIP $CTHOST" >> /etc/hosts
echo "$NETIP $NETHOST" >> /etc/hosts
echo "$CMPIP $CMPHOST" >> /etc/hosts
echo "$CMP2IP $CMP2HOST" >> /etc/hosts

INT_NET="openstack-int-network"

xe network-create name-label=$INT_NET

THEXAPIBR=$(xe network-list name-label=openstack-int-network params=bridge|awk '{print $5}')

vm_uuid=$(xe vm-list name-label=$CMPVMNAME minimal=true)
net=$(xe network-list bridge=xenapi --minimal)
vif=$(xe vif-create vm-uuid=$vm_uuid network-uuid=$net device=9)
xe vif-plug uuid=$vif
mac=$(xe vif-param-get uuid=$vif param-name=MAC)
xe vm-param-set uuid=$vm_uuid xenstore-data:vm-data/himn_mac=$mac

## Install XAPI plug-ins ##

chmod +x ./configfile/xapi.d/plugins/*
cp ./configfile/xapi.d/plugins/* /etc/xapi.d/plugins/

## Prepare for AMI type images ##
LOCAL_SR=$(xe sr-list name-label="Local storage" --minimal)
LOCALPATH="/var/run/sr-mount/$LOCAL_SR/os-guest-kernels"
mkdir -p "$LOCALPATH"
ln -s "$LOCALPATH" /boot/guest

## Modify dom0 for resize/migration support ##
LOCAL_SR=$(xe sr-list name-label="Local storage" --minimal)
IMG_DIR="/var/run/sr-mount/$LOCAL_SR/images"
mkdir -p "$IMG_DIR"
ln -s "$IMG_DIR" /images

## guest host logs for console hacks ##
dd if=/dev/zero of=/virtualfs bs=1024 count=102400
losetup /dev/loop1 /virtualfs
mkfs -t ext4 -m 1 -v /dev/loop1

log_dir="/var/log/xen/guest"
mkdir -p $log_dir
echo "/virtualfs  $log_dir  ext4  defaults 0 0" >> /etc/fstab
mount -a

mkdir -p ~/tools
cp ./configfile/rotate_xen_guest_logs.sh ~/tools/
chmod +x ~/tools/rotate_xen_guest_logs.sh

echo "* * * * * /root/tools/rotate_xen_guest_logs.sh" >> /var/spool/cron/root


echo "Your XAPI Bridge for Neutron Internal Bridge was XAPIBR="$THEXAPIBR" , input this result as XAPIBR value in briefcase file"
