#!/usr/bin/env python

# Copyright (c) 2013 OpenStack Foundation
# Copyright (c) 2013 Citrix Systems, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# NOTE: XenServer still only supports Python 2.4 in it's dom0 userspace
# which means the Nova xenapi plugins must use only Python 2.4 features

"""Returns the version of the nova plugins"""

import utils

# MAJOR VERSION: Incompatible changes
# MINOR VERSION: Compatible changes, new plugins, etc

# NOTE(sfinucan): 2.0 will be equivalent to the last in the 1.x stream

# 1.0 - Initial version.
# 1.1 - New call to check GC status
# 1.2 - Added support for pci passthrough devices
# 1.3 - Add vhd2 functions for doing glance operations by url
# 1.4 - Add support of Glance v2 api
# 1.5 - Added function for network configuration on ovs bridge
# 1.6 - Add function for network configuration on Linux bridge
# 1.7 - Add Partition utilities plugin
# 1.8 - Add support for calling plug-ins with the .py suffix
# 2.0 - Remove plugin files which don't have .py suffix
# 2.1 - Add interface ovs_create_port in xenhost.py
PLUGIN_VERSION = "2.1"


def get_version(session):
    return PLUGIN_VERSION

if __name__ == '__main__':
    utils.register_plugin_calls(get_version)