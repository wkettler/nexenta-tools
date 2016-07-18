#!/bin/bash
#
# post-install.sh
#
# NexentaStor post installation script.
#
# Copyright (C) 2016  Nexenta Systems
# William Kettler <william.kettler@nexenta.com>
#
# 2016-06-30 - Initial commit
#

#
# Generate a rollback checkpoint
#
echo "Creat a rollback checkpoint..."
nmc -c "setup appliance checkpoint create"

#
# Disable SMART
#
echo "Disabling SMART collector..."
nmc -c 'setup collector smart-collector disable'

echo "Disabling Auto SMART check..."
nmc -c 'setup trigger nms-autosmartcheck disable'

echo "Disabling SMART on all drives..."
nmc -c 'setup lun smart disable all'

#
# Enable SMB2
#
echo "Enabling SMB2..."
sharectl set -p smb2_enable=true smb

echo "Disabling oplocks..."
svccfg -s network/smb/server setprop smbd/oplock_enable = false
svcadm refresh network/smb/server
svcadm restart network/smb/server

#
# Increase swap
#
echo "Incresing swap..."
swap -d /dev/zvol/dsk/syspool/swap
zfs set volsize=`prtconf | grep "^Mem" | /usr/gnu/bin/awk '{printf "%d" , (($3*1024*1024)/4)'}` syspool/swap
swap -a /dev/zvol/dsk/syspool/swap

#
# Enable VAAI
#
echo "Enabling VAAI..."
echo "" >> /etc/system
echo "* Enable VAAI" >> /etc/system
echo "* `date`" >> /etc/system
echo "set stmf_sbd:HardwareAcceleratedInit = 1" >> /etc/system
echo "set stmf_sbd:HardwareAcceleratedLocking = 1" >> /etc/system
echo "set stmf_sbd:HardwareAcceleratedMove = 1" >> /etc/system

#
# Enable NMI
#
echo "Enabling NMI..."
echo "" >> /etc/system
echo "* Enable NMI" >> /etc/system
echo "* `date`" >> /etc/system
echo "set snooping=1" >> /etc/system
echo "set pcplusmp:apic_panic_on_nmi=1" >> /etc/system
echo "set apix:apic_panic_on_nmi = 1" >> /etc/system
