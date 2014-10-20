#!/bin/bash
#
# stmf-debug.sh
#
# Collects logs useful when troubleshooting stmf issues.
#
# William Kettler <william.kettler@nexenta.com>
# Copyright 2014, Nexenta Systems, Inc.
#

DATE=$(date +%Y-%m-%d:%H:%M:%S)
DIR="logs/${DATE}"
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

# Make log directory
mkdir -p "${DIR}"

echo ""
echo "Ctrl-C to stop monitoring..."
echo ""

background_log "dtrace/stmf_task_time_th.d 1000" "stmf_task_time_th.out"
background_log "dtrace/stmf_worker_queue.sh 5" "stmf_worker_queue.out"
background_log "dtrace/iscsit_sessions.d" "iscsit_session.out"

# Loop
while true; do
    read x
done
