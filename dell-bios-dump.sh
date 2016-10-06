#!/bin/bash
#
# dell-bios.sh
#
# Dump the Dell BIOS configuration.
#
# Copyright (C) 2016  Nexenta Systems
# William Kettler <william.kettler@nexenta.com>
#

ssh_racadm() {
    #
    # Remotely call racadm using ssh.
    #
    out=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no "$host" "racadm $@" 2>&1)
    # If sshpass fails best to exit immediately to avoid a hung iDRAC
    if [ $? -ne 0 ]; then
        echo "[FAILURE] sshpass"
        echo "$out"
        exit 1
    fi

    # We have no way of checking racadm return code so we must parse the output
    # for an ERROR string
    echo "$out" | grep -q ERROR
    if [ $? -eq 0 ]; then
        echo ""
        echo "[FAILURE] $@"
    else
        echo ""
        echo "[SUCCESS] $@"
    fi
    echo "-----"
    echo "$out"
}

# Check command line parameters
if [ $# -ne 1 ]; then
    echo Usage
    echo -e "\t$0 [user@]host"
    exit 1
fi

host=$1

# Prompt for password
read -s -p "Password :" pass
echo ""

settings=(BiosBootSettings IntegratedDevices MemSettings MiscSettings OneTimeBoot ProcSettings SataSettings SerialCommSettings SlotDisablement SysInformation SysProfileSettings SysSecurity TpmAdvanced)


for s in ${settings[@]}; do
    ssh_racadm get BIOS.${s}
done
