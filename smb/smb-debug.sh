#!/bin/bash
#
# smb-debug.sh
#
# Collects logs useful when troubleshooting smb issues.
#
# William Kettler <william.kettler@nexenta.com>
# Copyright 2014, Nexenta Systems, Inc.
#

# Command line args
IFACE=$1

DATE=$(date +%Y-%m-%d:%H:%M:%S)
DIR="logs/${DATE}"
IFACE=$1
declare -a PIDS

# Gracefully exit
trap cleanup SIGINT

cleanup() {
    for p in "${PIDS[@]}"; do
        kill "${p}"
    done
    exit
}

background() {
    $1 &
    PIDS=("${PIDS[@]}" "$!")
}

background_log() {
    $1 > "${DIR}/$2" &
    PIDS=("${PIDS[@]}" "$!")
}

# Verify interface is defined
if [ $# -ne 1 ]; then
    echo "Usage"
    echo -e "\t$0 interface"
    exit 1
fi

# Verify interface exists
dladm show-link | grep "^${IFACE} " > /dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] ${IFACE} does not exist"
    exit 1
fi

# Make log directory
mkdir -p "${DIR}"

echo ""
echo "Ctrl-C to stop monitoring..."
echo ""

background "snoop -q -d ${IFACE} -o ${DIR}/${IFACE}.snoop port 445"
# background "/usr/lib/smbsrv/dtrace/smbsrv.d -o ${DIR}/smbsrv.out"
# background "/usr/lib/smbsrv/dtrace/smbd-authsvc.d -p `pgrep smbd` -o ${DIR}/smbd-authsvc.out"
background_log "dtrace/smb_sessions.sh" "smb-sessions.out"
background_log "tail -f /var/svc/log/network-smb-server:default.log" "network-smb-server.log"
background_log "tail -f /var/svc/log/system-idmap:default.log" "system-idmap.log"
background_log "smbstat -rzu 5" "smbstat-rzu-5.out"
background_log "dtrace/smb_taskq_wait.d 1000" "smb-taskq-wait.out"
background_log "dtrace/smb_kstat.d" "smb-kstat.out"
background_log "dtrace/smb_req_time.d 1000" "smb-req-time-th.out"

# Loop
while true; do
    read x
done
