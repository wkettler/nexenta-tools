#!/usr/bin/env python

"""
rawcapacity.py

Display the raw capacity of all imported pools. Useful when sizing a license
capacity.

Copyright (c) 2014  Nexenta Systems
William Kettler <william.kettler@nexenta.com>
"""

import sys
import re
import subprocess
import signal


class Timeout(Exception):
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
    except Timeout as t:
        # Kill the running process
        phandle.kill()
        raise Timeout("command timeout of %ds exceeded" % timeout)
    except Exception as e:
        raise Execute(e)
    else:
        # Possible race condition where alarm doesn't disabled in time
        signal.alarm(0)

    # stdout may be None and we need to acct for it
    if stdout and stdout is not None:
        output = stdout.strip()
    else:
        output = None

    return retcode, output


def get_zpool_list():
    zpool = []
    cmd = "zpool list"
    retcode, output = execute(cmd)
    if retcode:
        print "[ERROR] %s" % output
        sys.exit(1)

    for line in output.splitlines():
        if line.startswith("NAME") or line.startswith("syspool"):
            continue
        zpool.append(line.split()[0].strip())

    return zpool


def get_zpool_disks(zpool):
    disks = []
    cmd = "zpool status %s" % zpool
    retcode, output = execute(cmd)
    if retcode:
        print "[ERROR] %s" % output
        sys.exit(1)

    for line in output.splitlines():
        # Log and Cache devices aren't included in the calculation
        if (line.strip().startswith("logs") or
            line.strip().startswith("cache") or
            line.strip().startswith("spares")):
            break
        elif re.search(r'(c[0-9]+t.*d[0-9]+\s)', line):
            disks.append(line.split()[0])

    return disks


def get_disk_sizes():
    sizes = {}
    cmd = "hddisco"
    retcode, output = execute(cmd)
    if retcode:
        print "[ERROR] %s" % output
        sys.exit(1)

    disk = None
    for line in output.splitlines():
        if line.startswith("="):
            disk = line.lstrip("=").strip()
        elif line.startswith("size "):
            sizes[disk] = int(line.split()[1].strip())

    return sizes


def main():
    print "Calculating required license capacity."
    print ""

    total = 0
    zpools = get_zpool_list()
    disk_sizes = get_disk_sizes()

    # Calculate raw size totals for each zpool
    for z in zpools:
        zpool_disks = get_zpool_disks(z)
        size = 0

        for d in zpool_disks:
           size += disk_sizes[d]
        total += size

        print "%s %d" % (z, size / 1024**4)

    print "-" * 10
    print "Total %d" % (total / 1024**4)
    print ""

if __name__ == "__main__":
    main()
