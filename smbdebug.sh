#!/bin/bash
#
# smbdebug.sh
#
# Collects logs useful when troubleshooting smb issues.
#

SMBSRV="/usr/lib/smbsrv/dtrace/smbsrv.d"
AUTHSVC="/usr/lib/smbsrv/dtrace/smbd-authsvc.d"
SNOOP="/usr/sbin/snoop"
PGREP="/usr/bin/pgrep"
DATE=`date +%s`
IFACE=$1
declare -a PIDS

# Gracefully exit
trap cleanup SIGINT

cleanup() {
    for p in "${PIDS[@]}"; do
        kill $p
    done
    exit
}

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

echo ""
echo "Ctrl-C to stop monitoring..."
echo ""

# Capture network traffic on the client interface
${SNOOP} -q -d ${IFACE} -o ${DATE}_${IFACE}.snoop not port 22 &
PIDS=("${PIDS[@]}" "$!")

# Monitor smbsrv internals
${SMBSRV} -o ${DATE}_smbsrv.out &
PIDS=("${PIDS[@]}" "$!")

# Monitor authsvc internals
${AUTHSVC} -p `${PGREP} smbd` -o ${DATE}_smbd-authsvc.out &
PIDS=("${PIDS[@]}" "$!")

# Loop
while true; do
    read x
done
