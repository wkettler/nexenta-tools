#!/usr/bin/sh
#
# This script will clear sd_errstats of a disk. If the disk is called sd3, the argument will be 3
#
# John McLaughlin <john.mclaughlin@nexenta.com>
#

if [ $# -ne 1 ]; then
	echo Usage : $0 disk-number
	exit
fi

# get the address in the kernel of kstat object
sd=`echo "*sd_state::softstate 0t$1" | mdb -kw`
es=`echo "$sd::print struct sd_lun un_errstats"| mdb -k | cut -d" " -f3`
ks=`echo  "$es::print kstat_t ks_data" |  mdb -k | cut -d" " -f3`

echo Resetting Hard Error

# get the address of the error counters, then set them to 0
ha=`echo  "$ks::print -a struct sd_errstats sd_harderrs.value.ui32" | mdb -k | cut -d" " -f1`

echo $ha/W 0 | mdb -kw

echo Resetting Soft Error
ha=`echo "$ks::print -a struct sd_errstats sd_softerrs.value.ui32" | mdb -k | cut -d" " -f1`

echo $ha/W 0 | mdb -kw

echo Resetting Tran Error
ha=`echo "$ks::print -a struct sd_errstats sd_transerrs.value.ui32" | mdb -k | cut -d" " -f1`

echo $ha/W 0 | mdb -kw
