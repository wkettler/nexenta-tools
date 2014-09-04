#!/usr/bin/bash
#
# clear-fma.sh
#
# Clear and reset FMA.
#

echo "Disabling FMA"
svcadm disable -st svc:/system/fmd:default
echo "FMA disabled"

echo "Deleting FMA logs"
find /var/fm/fmd -type f -exec rm {} \;
echo "FMA logs deleted"

echo "Enabling FMA"
svcadm enable -s svc:/system/fmd:default
echo "FMA enabled"

echo "Resetting FMA modules"
fmadm -q reset cpumem-retire
fmadm -q reset eft
fmadm -q reset io-retire
fmadm -q reset slow-io-de
echo "FMA modules reset"

echo 'Complete!'
