#!/bin/bash
pool=$1
if [[ -z "$pool" ]] 
then
  echo "Please specify a pool name"
  exit 1
fi

while true
do
echo Starting iozone loop on ${pool}
date
zfs create -o recordsize=32k -o compression=off ${pool}/iozone
(cd /volumes/${pool}/iozone && iozone -ec -r 32 -s 1048576m -l 6 -i 0 -i 1 -i 8)
zfs destroy ${pool}/iozone
echo Waiting 30 seconds before starting again...
sleep 30
done
