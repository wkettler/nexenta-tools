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
LOG="stmf-debug.log"
PERF_DIR="perflogs/${DATE}"
PID_LOG="/var/tmp/stmf-debug.pid"

ECHO="/usr/gnu/bin/echo -ne"
KILL="/usr/bin/kill"
RM="/usr/bin/rm"
NOHUP="/usr/bin/nohup"
MKDIR="/usr/bin/mkdir -p"

usage() {
    ${ECHO} "This is stmf-debug a performance gathering utility for "
    ${ECHO} "NexentaStor.\n"
    ${ECHO} "\n"
    ${ECHO} "USAGE\n"
    ${ECHO} "    $0 <command>\n"
    ${ECHO} "\n"
    ${ECHO} "COMMAND\n"
    ${ECHO} "    start  : start collecting performance data.\n"
    ${ECHO} "    status : displays any running dtrace scripts it has invoked.\n"
    ${ECHO} "    stop   : attempt to stop the dtrace scripts it started.\n"
    ${ECHO} "\n"
}

write_log() {
    msg="`date +%Y-%m-%d:%H:%M:%S` [$1] $2\n"
    ${ECHO} ${msg}
    ${ECHO} ${msg} >> ${LOG}
}

background() {
    write_log "INFO" "Running $1"
    ${NOHUP} $1 2>&1 &
    ${ECHO} "$!\n" >> ${PID_LOG}
}

background_log() {
    write_log "INFO" "Running $1"
    ${NOHUP} $1 > "${PERF_DIR}/$2" 2>&1 &
    ${ECHO} "$!\n" >> ${PID_LOG}
}

stop() {
    # Make sure the PID file exists o/w there isn't an active session
    if [ -f ${PID_LOG} ]; then
        write_log "INFO" "Stopping stmf-debug"
        # Make sure each pid is alive
        while read p; do
            write_log "INFO" "Killing process ID ${p}"
            ${KILL} "${p}"
        done < ${PID_LOG}

        ${RM} ${PID_LOG}
    else
        write_log "ERROR" "stmf-debug is not running"
    fi
}

start() {
    # Make performance log directory
    ${MKDIR} -p ${PERF_DIR}

    if [ -f ${PID_LOG} ]; then
        write_log "ERROR" "stmf-debug is already running"
        return
    fi

    write_log "INFO" "Starting monitoring scripts"

    # Define all collection scripts here
    background_log "dtrace/stmf_task_time_th.d 1000" "stmf_task_time_th.out"
    background_log "dtrace/stmf_worker_queue.sh 5" "stmf_worker_queue.out"
    background_log "dtrace/iscsit_sessions.d" "iscsit_sessions.out"

    write_log "INFO" "Monitoring scripts started"
}

status() {
    # Make sure the PID file exists o/w there isn't an active session
    if [ -f ${PID_LOG} ]; then
        write_log "INFO" "stmf-debug is running"
        # Make sure each pid is alive
        while read p; do
            ${KILL} -0 "${p}" 2> /dev/null
            if [ $? -eq 0 ]; then
                write_log "INFO" "Process ID ${p} is running"
            else
                write_log "ERROR" "Process ID ${p} has died"
            fi
        done < ${PID_LOG}
    else
        write_log "INFO" "stmf-debug is not running"
    fi
}

subcommand="$1"
case "${subcommand}" in
    start )
        start
        exit 0
        ;;
    stop )
        stop
        exit 0
	    ;;
    status )
        status
        exit 0
	    ;;
    * )
        usage
        exit 1
	    ;;
esac
