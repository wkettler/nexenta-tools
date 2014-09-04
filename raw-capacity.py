#!/usr/bin/env python

"""
raw-capacity.py

Display the raw capacity of all imported pools. Useful when sizing a license.

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
    """
    Return all zpools w/the exception of syspool.

    Inputs:
        None
    Outputs:
        zpool (list): zpools
    """
    zpool = []
    cmd = "zpool list"
    retcode, output = execute(cmd)
    if retcode:
        print "[ERROR] %s" % output
        sys.exit(1)

    for line in output.splitlines():
        # Ignore the header and syspool
        if line.startswith("NAME") or line.startswith("syspool"):
            continue
        zpool.append(line.split()[0].strip())

    return zpool


def get_zpool_disks(zpool):
    """
    Return the device IDs for a give zpool. The list excludes any log, cache
    or spare devices since they are not included in the capacity calculation.

    Inputs:
        zpool (str): zpool name
    Outputs:
        disks (list): All device IDs in the zpool
    """
    disks = []
    cmd = "zpool status %s" % zpool
    retcode, output = execute(cmd)
    if retcode:
        print "[ERROR] %s" % output
        sys.exit(1)

    for line in output.splitlines():
        # Log, cache and spares aren't included in the calculation
        if (line.strip().startswith("logs") or
                line.strip().startswith("cache") or
                line.strip().startswith("spares")):
            break
        elif re.search(r'(c[0-9]+t.*d[0-9]+\s)', line):
            disks.append(line.split()[0])

    return disks


def get_disk_sizes():
    """
    Return a dictionary of device IDs and their associated sizes in bytes.

    Inputs:
        None
    Outputs:
        sizes (dict): Device sizes
    """
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
    print "Calculating raw pool capacity."
    print "NOTE log, cache, and spares are not included in the calculation."
    print ""

    total = 0
    zpools = get_zpool_list()
    disk_sizes = get_disk_sizes()

    # Calculate raw size totals for each zpool
    for z in zpools:
        zpool_disks = get_zpool_disks(z)
        size = 0

        # Sum the capacities of all the zpool disks
        for d in zpool_disks:
            size += disk_sizes[d]
        total += size

        # Print the zpool total
        print "%20s %5.1f TB" % (z, float(size) / 1024**4)

    # Print the overall total
    print "%20s %s" % (" ", "-" * 8)
    print "%20s %5.1f TB" % ("TOTAL", float(total) / 1024**4)
    print ""

if __name__ == "__main__":
    main()
