#!/bin/bash
#
# stmf_worker_queue.sh
#
# Print current stmf queue depth and the number of allocated worker threads.
#
# William Kettler <william.kettler@nexenta.com>
# Copyright 2014, Nexenta Systems, Inc.
#

# Verify sleep interval is defined
if [ $# -ne 1 ]; then
    echo "Usage"
    echo -e "\t$0 <interval>"
    exit 1
fi

# Print min/max stmf workers
# These values are tunable
echo stmf_min_nworkers/D | mdb -k | tail -1
echo stmf_max_nworkers/D | mdb -k | tail -1
echo ""

while true; do
    date
    echo stmf_cur_ntasks/D | mdb -k | tail -1
    echo stmf_nworkers_cur/D | mdb -k | tail -1
    echo ""

    sleep $1
done
