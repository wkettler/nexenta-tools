#!/usr/bin/python

"""
disk-info.py

Print disk information in CSV format.

Copyright (c) 2014  Nexenta Systems
William Kettler <william.kettler@nexenta.com>
"""

import sys
import signal
import subprocess
import re


class Timeout(Exception):
    pass


class Execute(Exception):
    pass


def alarm_handler(signum, frame):
    raise Timeout


def execute(cmd, timeout=None):
    """
    Execute a command in the default shell. If a timeout is defined the command
    will be killed if the timeout is exceeded.

    Inputs:
        cmd     (str): Command to execute
        timeout (int): Command timeout in seconds
    Outputs:
        retcode  (int): Return code
        output  (list): STDOUT/STDERR
    """
    # Define the timeout signal
    if timeout:
        signal.signal(signal.SIGALRM, alarm_handler)
        signal.alarm(timeout)

    try:
        # Execute the command and wait for the subprocess to terminate
        # STDERR is redirected to STDOUT
        phandle = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT)

        # Read the stdout/sterr buffers and retcode
        stdout, stderr = phandle.communicate()
        retcode = phandle.returncode
    except Timeout, t:
        # Kill the running process
        phandle.kill()
        raise Timeout("command timeout of %ds exceeded" % timeout)
    except Exception, err:
        raise Execute(err)
    else:
        # Possible race condition where alarm isn't disabled in time
        signal.alarm(0)

    # stdout may be None and we need to acct for it
    if stdout and stdout is not None:
        output = stdout.strip()
    else:
        output = None

    return retcode, output


def execute_cmd(cmd, timeout=None):
    """
    Execute a command as defined in the config file and write it to the SIG
    document.

    Inputs:
        cmd     (str): Command to execute
        timeout (int): Command timeout in seconds
    Outputs:
        None
    """
    try:
        retcode, output = execute(cmd, timeout=timeout)
    except Exception, err:
        sys.stderr.write("[ERROR] command execution failed \"%s\"\n" % cmd)
        sys.stderr.write("[ERROR] %s\n" % str(err))
        sys.exit(1)

    # Check the command return code
    if retcode:
        sys.stderr.write("[ERROR] command execution failed \"%s\"\n" % cmd)
        sys.stderr.write("[ERROR] %s\n" % output)
        sys.exit(1)

    return output


def execute_nmc(cmd, timeout=None):
    """
    Execute an NMC command as defined in the config file and write it to the
    SIG document.

    Inputs:
        cmd     (str): NMC command to execute
        timeout (int): Command timeout in seconds
    Outputs:
        None
    """
    nmc = "nmc -c \"%s\"" % cmd
    try:
        retcode, output = execute(nmc, timeout=timeout)
    except Exception, err:
        sys.stderr.write("[ERROR] command execution failed \"%s\"\n" % cmd)
        sys.stderr.write("[ERROR] %s\n" % str(err))
        sys.exit(1)

    # Check the command return code
    if retcode:
        sys.stderr.write("[ERROR] command execution failed \"%s\"\n" % cmd)
        sys.stderr.write("[ERROR] %s\n" % output)
        sys.exit(1)

    return output


def get_hddisco():
    """
    Return parsed hddisco output.

    Inputs:
        None
    Outputs:
        hddisco (dict): Parsed hddisco output
    """
    hddisco = {}

    # Execute hddisco command
    output = execute_cmd("hddisco", 300)

    # Iterate over each line of stdout
    for line in output.splitlines():
        path = 0
        # If the line begins with '='
        if line.startswith("="):
            current = line.lstrip('=').strip()
            hddisco[current] = {}
        # If the line begins with 'P'
        elif line.startswith('P'):
            continue
        else:
            k, v = [x.strip() for x in line.split(None, 1)]
            hddisco[current][k] = v

    return hddisco

def get_slotmap():
    """
    Return parsed slotmap.

    Inputs:
        None
    Outputs:
        slotmap (dict): Parsed slotmap output
    """
    slotmap = {}

    cmd = "show lun slotmap"
    output = execute_nmc(cmd, timeout=300)

    for line in output.splitlines():
        if "Unmapped disks" in line:
            break
        elif re.search(r'(c[0-9]+t.*d[0-9]+\s)', line):
            lun, jbod, slot = line.split()[:-1]
            if jbod not in slotmap:
                slotmap[jbod] = {}
            slotmap[jbod][int(slot)] = lun

    return slotmap


def main():
    execute_nmc("setup jbod rescan")
    slotmap = get_slotmap()
    hddisco = get_hddisco()

    for j in slotmap:
        for s in slotmap[j]:
            devid = slotmap[j][s]
            print ",".join([j, str(s), devid,
                            hddisco[devid]["size_str"],
                            hddisco[devid]["vendor"],
                            hddisco[devid]["product"],
                            hddisco[devid]["serial"]])

if __name__ == "__main__":
    main()
