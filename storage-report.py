#!/usr/bin/env python

"""
storage-report.py

Report storage utilization.

Copyright (c) 2014  Nexenta Systems
William Kettler <william.kettler@nexenta.com>
"""

import sys
import subprocess
import re
import time

unit = 1024 ** 3


class Execute(Exception):
    pass


class Retcode(Exception):
    pass


def execute(cmd):
    """
    Execute a command in the default shell.

    Inputs:
        cmd     (str): Command to execute
        timeout (int): Command timeout in seconds
    Outputs:
        output (list): STDOUT, STDERR is piped to STDOUT
    """
    try:
        # Execute the command and wait for the subprocess to terminate
        phandle = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT)
        # Wait for the command to return
        phandle.poll()

        # Read the stdout/sterr buffers and retcode
        stdout, stderr = phandle.communicate()
        retcode = phandle.returncode
    except Exception, e:
        raise Execute(e)

    # Split lines into list
    if stdout and stdout is not None:
        output = stdout
    else:
        output = None

    # Exit if command fails
    if retcode:
        sys.stderr.write("[ERROR] unable to execute \"%s\"" % cmd)
        sys.stderr.write(output)
        sys.exit(1)

    return output


def pprint_table(table):
    """
    Pretty print table.

    Inputs:
        table (list): table
    Outputs:
        None
    """
    padding = []

    # Get the max width of each column
    for i in range(len(table[0])):
        padding.append(max([len(row[i]) for row in table]))

    for row in table:
        for i in range(len(row)):
            col = row[i].rjust(padding[i] + 2)
            print col,
        print ""


def get_zpools():
    """
    Return a list of zpools on the system excluding syspool.

    Inputs:
        None
    Outputs:
        zpools (list): zpools
    """
    zpools = []

    cmd = "zpool list  -H -o name"
    output = execute(cmd)

    # Ignore syspool
    for pool in output.splitlines():
        if pool == 'syspool':
            continue
        else:
            zpools.append(pool)

    return zpools


def get_usedsnap(zpool):
    """
    Get space used by all snapshots including direct descendents and snapshots
    of child datasets and volumes.

    Inputs:
        zpool (str): zpool
    Outputs:
        usedsnap (str): Used snapshot space
    """
    cmd = "zfs list -rHp -o usedsnap  %s" % zpool
    output = execute(cmd)

    # Sum each line
    usedsnap = "%.2f" % (sum([float(l) for l in output.splitlines()]) / unit)

    return usedsnap


def get_usedds(zpool):
    """
    Get spaced used by all datasets and volumes including direct descendents
    and those of child datasets and volumes.

    Inputs:
        zpool (str): zpool
    Output:
        useds (int): Used dataset space
    """
    cmd = "zfs list -rHp -o usedds %s" % zpool
    output = execute(cmd)

    # Sum each line
    usedds = "%.2f" % (sum([float(l) for l in output.splitlines()]) / unit)

    return usedds


def get_usedrefreserv(zpool):
    """
    Get space used by all refreservations including those reservations on all
    direct and indirect descendents.

    Inputs:
        zpool (str): zpool
    Ouputs:
        usedrefreserv (int): Used refreservation space
    """
    cmd = "zfs list -rHp -o usedrefreserv %s" % zpool
    output = execute(cmd)

    # Sum each line
    usedrefreserv = "%.2f" % (sum([float(l) for l in output.splitlines()]) /
                              unit)

    return usedrefreserv


def get_used(zpool):
    """
    Total space used which is the sum of all direct and indirect snapshot,
    datasets, volumes, and reservations descendents.

    Inputs:
        zpool (str): zpool
    Outputs:
        used (int): used capacity
    """
    cmd = "zfs list -Hp -o used %s" % zpool
    output = execute(cmd)

    used = "%.2f" % (float(output.strip()) / unit)

    return used


def get_allocated(zpool):
    """
    Get space allocated, i.e actual space consumed on disk.

    Inputs:
        zpool (str): zpool
    Outputs:
        allocated (int): allocated space
    """
    cmd = "zpool list -Hp -o allocated %s" % zpool
    output = execute(cmd)

    allocated = "%.2f" % (float(output.strip()) / unit)

    return allocated


def get_size(zpool):
    """
    Get zpool size.

    Inputs:
        zpool (str): zpool
    Outputs:
        size (int): zpool size
    """
    cmd = "zpool list -Hp -o size %s" % zpool
    output = execute(cmd)

    size = "%.2f" % (float(output.strip()) / unit)

    return size


def get_hostname():
    """
    Get hostname.

    Inputs:
        None
    Ouputs:
        hostname (str): hostname
    """
    hostname = execute("hostname").strip()

    return hostname


def main():
    date_str = time.strftime('%Y%m%d-%H%M', time.localtime(int(time.time())))
    hostname = get_hostname()
    ofile = "%s-%s-storage-report.csv" % (date_str, hostname)
    table = []

    # Open output file
    try:
        fh = open(ofile, 'w')
    except Exception, e:
        sys.stderr.write("[ERROR] opening %s" % ofile)
        sys.stderr.write(e)
        sys.exit(1)

    # Header
    header = ["Pool", "Size", "Allocated", "Used", "Used Snapshot",
              "Used Data", "Used RefReservation"]
    fh.write("%s\n" % ",".join(header))
    table.append(header)

    # Iterate over each pool
    for z in get_zpools():
        row = [z, get_size(z), get_allocated(z), get_used(z), get_usedsnap(z),
               get_usedds(z), get_usedrefreserv(z)]

        fh.write("%s\n" % ",".join([str(x) for x in row]))
        table.append(row)

    # Close file
    fh.close()

    pprint_table(table)

    print ""
    print "Output save to %s." % ofile


if __name__ == "__main__":
    main()
