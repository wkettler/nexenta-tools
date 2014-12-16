#!/bin/bash
#
# dell-bios.sh
#
# Configure Dell BIOS per best practices.
#
# Copyright (C) 2014  Nexenta Systems
# William Kettler <william.kettler@nexenta.com>
#
# ftp://ftp.dell.com/Manuals/all-products/esuprt_electronics/esuprt_software/esuprt_remote_ent_sys_mgmt/integrated-dell-remote-access-cntrllr-7-v1.30.30_Reference%20Guide_en-us.pdf
#

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
    out=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no "$host" "racadm set $1 $2" 2>&1)
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
        echo "[FAILURE] $1 $2"
        echo "$out"
    else
        echo "[SUCCESS] $1 $2"
    fi
}

racadm_commit() {
    #
    # commit changes 
    # see http://jonamiki.com/2014/10/18/racadm-change-bios-settings-create-commit-job-reboot-and-apply/
    #
    out=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no "$host" "racadm jobqueue create BIOS.Setup.1-1" 2>&1)
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
        echo "[FAILURE] jobqueue create BIOS.Setup.1-1"
        echo "$out"
    else
        echo "[SUCCESS] jobqueue create BIOS.Setup.1-1"
    fi
}

racadm_reboot() {
    #
    # Issues a power-cycle operation on the managed server. This action is
    # similar to pressing the power button on the system's front panel to power
    # down and then power up the system.
    #
    out=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no "$host" "racadm serveraction powercycle" 2>&1)
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
        echo "[FAILURE] serveraction powercycle"
        echo "$out"
    else
        echo "[SUCCESS] serveraction powercycle"
    fi
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

# commit the change
racadm_commit

# Reboot
echo "A reboot is required for the new settings to take effect."
if prompt "Reboot now?"; then
    racadm_reboot
fi
