#!/bin/bash
#
# dell-bios.sh
#
# Configure Dell BIOS per best practices.
#
# Copyright (C) 2014  Nexenta Systems
# William Kettler <william.kettler@nexenta.com>
#
# See ftp://ftp.dell.com/Manuals/all-products/esuprt_electronics/esuprt_software/esuprt_remote_ent_sys_mgmt/integrated-dell-remote-access-cntrllr-7-v1.30.30_Reference%20Guide_en-us.pdf
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
        echo "Invalid input."
        prompt "$1"
    fi
}

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
        echo "[FAILURE] $@"
        echo "$out"
    else
        echo "[SUCCESS] $@"
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
echo ""

# System profile
ssh_racadm set BIOS.SysProfileSettings.SysProfile PerfOptimized

# Disable virtualization
ssh_racadm set BIOS.ProcSettings.ProcVirtualization Disabled

# Disable embedded SATA
ssh_racadm set BIOS.SataSettings.EmbSata Off

# Disable I/OAT DMA engine
ssh_racadm set BIOS.IntegratedDevices.IoatEngine Disabled

# Disable SR-IOV
ssh_racadm set BIOS.IntegratedDevices.SriovGlobalEnable Disabled

# Clean recovery from power failure
ssh_racadm set BIOS.SysSecurity.AcPwrRcvry Last
ssh_racadm set BIOS.SysSecurity.AcPwrRcvryDelay Immediate

# Boot mode
ssh_racadm set BIOS.BiosBootSettings.BootMode Bios

# PCI slot disablement
ssh_racadm set BIOS.SlotDisablement.Slot1 BootDriverDisabled
ssh_racadm set BIOS.SlotDisablement.Slot2 BootDriverDisabled
ssh_racadm set BIOS.SlotDisablement.Slot3 BootDriverDisabled
ssh_racadm set BIOS.SlotDisablement.Slot4 BootDriverDisabled
ssh_racadm set BIOS.SlotDisablement.Slot5 BootDriverDisabled
ssh_racadm set BIOS.SlotDisablement.Slot6 BootDriverDisabled
ssh_racadm set BIOS.SlotDisablement.Slot7 BootDriverDisabled

# Commit the changes on next reboot
# See http://jonamiki.com/2014/10/18/racadm-change-bios-settings-create-commit-job-reboot-and-apply/
ssh_racadm jobqueue create BIOS.Setup.1-1

# Reboot
echo "A reboot is required for the new settings to take effect."
if prompt "Reboot now?"; then
    ssh_racadm serveraction powercycle
fi
