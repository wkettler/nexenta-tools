#!/usr/bin/bash
#
# install-check.sh
#
# Used to compare cluster node configs after installation.
#
# Copyright (c) 2014  Nexenta Systems
# John McLaughlin <john.mclaughlin@nexenta.com>
#

echo Nexenta Install Check for node `hostname`

echo
echo /etc/system
echo
cat /etc/system | sed -e '/^\*/d' -e '/^[\t ]*$/d'

echo
echo /etc/netmasks
echo
cat /etc/netmasks | sed -e '/^#/d' -e '/^[\t ]*$/d'

echo
echo /etc/hosts
echo
cat /etc/hosts | sed -e '/^#/d' -e '/^[\t ]*$/d'

echo
echo ifconfig -a
echo
ifconfig -a

echo
echo cat /etc/defaultrouter
echo
cat /etc/defaultrouter

echo
echo netstat -nr
echo
netstat -nr

echo
echo /etc/default/nfs
echo
cat /etc/default/nfs | sed -e '/^#/d' -e '/^[\t ]*$/d'

echo
echo sasinfo hba -v
echo
sasinfo hba -v
echo

echo
echo /var/lib/nza/triggers
echo
md5sum /var/lib/nza/triggers/*

echo
echo /usr/lib/fm/fmd/plugins/sensor-transport.conf
echo
cat /usr/lib/fm/fmd/plugins/sensor-transport.conf | sed -e '/^#/d' -e '/^[\t ]*$/d'


echo
echo "Count of disks with Vendor name and firmware"
echo
iostat -En | grep Vendor | sed 's/Serial.*//' | sort  | uniq -c

echo
echo Are there multiple paths to the disks?
echo
mpathadm list lu | sort | uniq -c

echo
echo current resilver throttle setting:
echo
echo zfs_resilver_delay/D |mdb -k
echo zfs_resilver_min_time_ms/D |mdb -k

echo
echo current scrub delay
echo
echo "zfs_scrub_delay/D" | mdb -k


echo
echo Are there hard errors for any disks?
echo
iostat -en | grep -v '0 c'

echo
echo List PCI devices
echo
lspci -v

echo
echo "/kernel/drv/scsi_vhci.conf"
echo
cat /kernel/drv/scsi_vhci.conf | sed -e '/^#/d' -e '/^[\t ]*$/d'

echo
echo "/etc/resolv.conf"
cat /etc/resolv.conf
echo

echo
echo "Check Current C-States"
kstat -p cpu_info:::current_cstate
echo
echo

echo "Check MAX C-States"
kstat -p cpu_info:::supported_max_cstates
echo

echo
echo showmount -a -e
echo
showmount -a -e

echo
echo "network interfaces"
echo
dladm  show-phys | sort
dladm  show-aggr | sort
dladm  show-link | sort


echo
echo "Check cluster license"
echo
/opt/HAC/RSF-1/bin/rsfmon -v 2>&1

echo
echo Cluster res files
echo
if [ -n "/opt/HAC/RSF-1/etc/.res*" ]; then
  ls -l /opt/HAC/RSF-1/etc/.res*
  md5sum /opt/HAC/RSF-1/etc/.res*
fi

echo
echo "zfs list status"
echo
zfs list

echo
echo Pool properties
echo
zpool list | grep -v NAME | while read pool stuff
do
  echo zfs get all $pool
  zfs get all $pool
  echo
done


echo "zpool status"
echo
zpool status

#echo
# this block needs work to be general
#echo "zpool status for each pool with slot numbers listed"
#echo
#nmc -c "show lun slotmap" | sed 's/[\t ]*$//' > /tmp/slotmap
#zpool list | sed -e '/^NAME/d' -e '/^syspool/d' | while read zp skip
#do
#	echo zpool $zp
#	zpool status $zp | \
#	 sed 's/^[\t ]*//' | \
#	 egrep 'raidz|c15' | \
#	 sed 's/ONLINE       0     0     0//' | \
#	 sed 's/^c15/grep c15/' | \
#	 sed 's/^raid/echo raid/' | \
#	 sed 's+grep.*+& /tmp/slotmap+' | \
#	 sh
#done

echo
echo Domainname
svccfg -s smb/server listprop smbd/domain_name | awk -F' ' '{print $3}'
echo

echo
echo Joined to AD?
smbadm list
echo

#starting the nmc command takes a log time, so we feed a bunch of command to one instance of nmc
echo
echo "nms settings"
stty columns 132
(
(
cat <<EOF
show network gateway
show network nameservers
show network ssh-bindings
show appliance mailer
show jbod
show lun slotmap
show lun smartstat
show appliance sysinfo
show appliance license
show appliance timezone
show plugin installed
show zvol
show auto-scrub
show auto-sync
show auto-snap
show appliance nms property
show group rsf-cluster
show appliance checkpoint
EOF
) | while read command
do
	echo
	echo $command
	echo
done
) | nmc | sed 's/[\t ]*$//'


echo "sorted nms settings"
(
(
cat <<EOF
show group
show network service
show trigger ses-check property
show appliance runners
EOF
) | while read command
do
	echo "----------------------------------"
	echo "$command"
	echo "----------------------------------"
	nmc -c "$command" | sed 's/[\t ]*$//' | sort
	echo
done
)

echo
echo Check for Fault Management Error
echo
echo fmadm faulty
fmadm faulty
echo

echo check the FM error logs
echo /usr/sbin/fmdump -eV -t7day
echo
/usr/sbin/fmdump -eV -t7day
