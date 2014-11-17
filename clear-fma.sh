#!/usr/bin/bash
#
# clear-fma.sh
#
# Clear and reset FMA.
#

echo "Disabling FMA"
svcadm disable -st svc:/system/fmd:default

echo "Deleting FMA logs"
find /var/fm/fmd -type f -exec rm {} \;

echo "Enabling FMA"
svcadm enable -s svc:/system/fmd:default

echo "Resetting FMA modules"
fmadm -q reset cpumem-retire
fmadm -q reset eft
fmadm -q reset io-retire
fmadm -q reset slow-io-de

echo 'Complete!'
