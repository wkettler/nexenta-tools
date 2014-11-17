#!/bin/bash
#
# stmf_worker_queue.sh
#
# Print current stmf queue depth and the number of allocated worker threads.
#
# William Kettler <william.kettler@nexenta.com>
# Copyright 2014, Nexenta Systems, Inc.
#

ECHO="/usr/gnu/bin/echo"
MDB="/usr/bin/mdb"
TAIL="/usr/xpg4/bin/tail"
TR="/usr/xpg6/bin/tr"
CUT="/usr/bin/cut"
PRINTF="/usr/bin/printf"

# Make sure only root can run script
if [[ $EUID -ne 0 ]]; then
    ${ECHO} "This script must be run as root" 1>&2
    exit 1
fi

# Verify sleep interval is defined
if [ $# -ne 1 ]; then
    ${ECHO} "Usage"
    ${ECHO} -e "\t$0 <interval>"
    exit 1
fi

# Print min/max stmf workers
# These values are tunable
${ECHO} stmf_min_nworkers/D | mdb -k | tail -1
${ECHO} stmf_max_nworkers/D | mdb -k | tail -1
${ECHO} ""

${PRINTF} "%-40s%-10s%-10s\n" "DATE" "NTASKS" "NWORKERS"
while true; do
    date=$(date)
    ntasks=$(${ECHO} stmf_cur_ntasks/D | ${MDB} -k | ${TAIL} -1 | ${CUT} -f2 -d":" | ${TR} -d ' ')
    nworkers=$(${ECHO} stmf_nworkers_cur/D | ${MDB} -k | ${TAIL} -1 | ${CUT} -f2 -d":" | ${TR} -d ' ')
    ${PRINTF} "%-40s%-10s%-10s\n" "${date}" "${ntasks}" "${nworkers}"

    sleep $1
done
