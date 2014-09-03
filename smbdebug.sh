#!/bin/bash
#
# smb-debug.sh
#
# Collects logs useful when troubleshooting smb issues.
#

SMBSRV="/usr/lib/smbsrv/dtrace/smbsrv.d"
AUTHSVC="/usr/lib/smbsrv/dtrace/smbd-authsvc.d"
SNOOP="/usr/sbin/snoop"
PGREP="/usr/bin/pgrep"
DATE=`date +%s`
IFACE=$1

# Verify all the binaries exist
for i in ${SMBSRV} ${AUTHSVC} ${SNOOP} ${PGREP}; do
	command -v $i &>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] ${i} not found"
        exit 1
    fi
done

# Verify command line params
# Work in progress

# Capture network traffic on the client interface
${SNOOP} -q -d ${IFACE} -o ${DATE}_${IFACE}.snoop not port 22 &

# Monitor smbd internals
${SMBSRV} -o ${DATE}_smbsrv.out &
${AUTHSVC} -p `${PGREP} smbd` -o ${DATE}_smbd-authsvc.out &
