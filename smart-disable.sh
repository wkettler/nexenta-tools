#!/bin/bash
#
# smart-disable.sh
#
# Disable SMART on all disks.
#
# Copyright (C) 2014  Nexenta Systems
# William Kettler <william.kettler@nexenta.com>
#

# Disover disks
disks=$(nmc -c 'show lun slotmap' | grep c*t*d0 | cut -d" " -f1)

echo "Disabling SMART."

# Disable SMART on each disk
(
for d in $disks; do
    echo ""
    echo "setup lun smart disable -d $d"
    echo ""
done
) | nmc

# This should return if above succeeded o/w we must disable manually
nmc -c 'show lun smartstat' | less
