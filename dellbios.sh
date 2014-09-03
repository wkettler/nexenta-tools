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

HOST=$1
PASS=$2

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

    sshpass -p $PASS ssh -o StrictHostKeyChecking=no $HOST "racadm set $1 $2"
    return $?
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
