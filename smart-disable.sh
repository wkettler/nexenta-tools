#!/bin/bash
#
# smart-disable.sh
#
# Disable SMART on all disks.
#
# Copyright (C) 2015  Nexenta Systems
# William Kettler <william.kettler@nexenta.com>
#

echo "Disabling SMART collector..."
nmc -c 'setup collector smart-collector disable'

echo "Disabling Auto SMART check..."
nmc -c 'setup trigger nms-autosmartcheck disable'

echo "Disabling SMART on all drives..."
nmc -c 'setup lun smart disable all'

# Review SMART status on each drive
nmc -c 'show lun smartstat' | less
