#!/bin/bash
#
# smb_sessions.sh
#
# Print active SMB sessions.
#

while true; do
    echo ""
    date
    echo "::smbsess -ruv" | mdb -k
    sleep 30
done
