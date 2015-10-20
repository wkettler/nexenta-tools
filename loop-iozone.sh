#!/bin/bash
#
# Loop iozone for pool burn in.
#

pool=$1
if [[ -z "$pool" ]] 
then
  echo "Please specify a pool name."
  exit 1
fi

# Gracefully exit
trap cleanup SIGINT

cleanup() {
    echo "User killed test."
    destroy
    exit
}

create() {
    echo "Creating iozone test folder."
    zfs create -o recordsize=32k -o compression=off ${pool}/iozone
}

destroy() {
    echo "Destroying zfs folder."
    zfs destroy ${pool}/iozone
}

create
while true; do
    echo "Starting iozone on ${pool}."
    date
    (cd /volumes/${pool}/iozone && iozone -ec -r 32 -s 102400m -l 6 -i 0 -i 1 -i 8)
    echo "Waiting 30 seconds before next iteration."
    sleep 30
done
