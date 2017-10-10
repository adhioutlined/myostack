#!/bin/bash

## Deploy database ##
sh ./db_deploy.sh
## Deploy identity ##
sh ./keystone_deploy.sh
## Deploy image service ##
sh ./glance_deploy.sh
## Deploy compute service ##
sh ./nova_ct_deploy.sh
## Deploy Networking service ##
sh ./neutron_ct_deploy.sh
