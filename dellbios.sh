#!/bin/bash
#
# dellbios.sh
#
# Configure Dell BIOS per best practices.
#
# Copyright (C) 2014  Nexenta Systems
# William Kettler <william.kettler@nexenta.com>
#
# ftp://ftp.dell.com/Manuals/all-products/esuprt_electronics/esuprt_software/esuprt_remote_ent_sys_mgmt/integrated-dell-remote-access-cntrllr-7-v1.30.30_Reference%20Guide_en-us.pdf
#

host=$1
pass=$2
red='\e[0;31m'
green='\e[0;32m'
nc='\e[0m'

prompt() {
    #
    # Prompt user with a yes or no question.
    #
    read -p "$1 [y|n]: "

    # If yes return 0
    if [[ $REPLY == "y" ]]; then
        return 0
    # If no return 1
    elif [[ $REPLY == "n" ]]; then
        return 1
    # If 'y' or 'n' was not entered re-prompt
    else
        $ECHO "Invalid input."
        prompt "$1"
    fi
}

racadm_set() {
    #
    # Set remote BIOS settings using ssh/racadm.
    #
    out=$(sshpass -p $pass ssh -o StrictHostKeyChecking=no $host "racadm set $1 $2" 2>&1)
    # If sshpass fails best to exit immediately to avoid a hung iDRAC
    if [ $? -ne 0 ]; then
        echo -e "[${red}FAILURE${nc}] sshpass"
        echo $out
        exit 1
    fi

    # We have no way of checking racadm return code so we must parse the output
    # for an ERROR string
    echo $out | grep -q ERROR
    if [ $? -eq 0 ]; then
        echo -e "[${red}FAILURE${nc}] $1 $2"
        echo $out
    else
        echo -e "[${green}SUCCESS${nc}] $1 $2"
    fi
}

# System profile
racadm_set BIOS.SysProfileSettings.SysProfile PerfOptimized

# Disable virtualization
racadm_set BIOS.ProcSettings.ProcVirtualization Disabled

# Disable embedded SATA
racadm_set BIOS.SataSettings.EmbSata Off

# Disable I/OAT DMA engine
racadm_set BIOS.IntegratedDevices.IoatEngine Disabled

# Disable SR-IOV
racadm_set BIOS.IntegratedDevices.SriovGlobalEnable Disabled

# Clean recovery from power failure
racadm_set BIOS.SysSecurity.AcPwrRcvry Last
racadm_set BIOS.SysSecurity.AcPwrRcvryDelay Immediate

# Boot mode
racadm_set BIOS.BiosBootSettings.BootMode Bios

# PCI slot disablement
racadm_set BIOS.SlotDisablement.Slot1 BootDriverDisabled
racadm_set BIOS.SlotDisablement.Slot2 BootDriverDisabled
racadm_set BIOS.SlotDisablement.Slot3 BootDriverDisabled
racadm_set BIOS.SlotDisablement.Slot4 BootDriverDisabled
racadm_set BIOS.SlotDisablement.Slot5 BootDriverDisabled
racadm_set BIOS.SlotDisablement.Slot6 BootDriverDisabled
racadm_set BIOS.SlotDisablement.Slot7 BootDriverDisabled

# Reboot
echo "A reboot is required for the new settings to take effect."
if prompt "Reboot now?"; then
    reboot
fi
