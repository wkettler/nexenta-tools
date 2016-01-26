#!/usr/bin/env python

"""
storage-report.py

Report storage utilization.

Supported on NexentaStor 4.0.3 or greater.

Copyright (c) 2016  Nexenta Systems
William Kettler <william.kettler@nexenta.com>
"""

import sys
import time
import commands
import socket


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

    # Print header
    header = table.pop(0)
    width = []
    for index, item in enumerate(header):
        width.append(len(item))
        col = item.rjust(padding[index] + 2)
        print col,
    print ""

    # Print header delimiter
    for index, item in enumerate(width):
        under = "-" * item
        col = under.rjust(padding[index] + 2)
        print col,
    print ""

    # Print table contents
    for row in table:
        for index, item in enumerate(row):
            col = item.rjust(padding[index] + 2)
            print col,
        print ""


def get_hostname():
    """
    Get hostname.

    Inputs:
        None
    Ouputs:
        hostname (str): hostname
    """
    hostname = socket.gethostname()

    return hostname


def get_zfs_space(unit):
    """
    Parse the output of `zfs list -o space` and convert to the defined unit.

    Inputs:
        unit (str): Unit, e.g. B,K,M,G,T
    Outputs:
        table (list): Pased output of `zfs list -o space`
    """
    units = {
        "B": 1,
        "K": 1024,
        "M": 1024 ** 2,
        "G": 1024 ** 3,
        "T": 1024 ** 4
    }
    table = []

    retcode, output = commands.getstatusoutput("zfs list -p -o space")
    if retcode:
        print "[ERROR] Command execution failed"
        print output
        sys.exit(1)

    # Iterate over the command output
    header = True
    for line in output.splitlines():
        row = line.split()
        if header:
            header = False
        else:
            for i in range(1, len(row)):
                row[i] = "%.1f%s" % (float(int(row[i]) / units[unit]), unit)
        table.append(row)

    return table


def main():
    """
    Main function.
    """
    unit = "K"
    date = time.strftime('%Y%m%d-%H%M', time.localtime(int(time.time())))
    hostname = get_hostname()
    ofile = "%s-%s-storage-report.csv" % (date, hostname)

    # Open output file
    try:
        fhandle = open(ofile, 'w')
    except IOError, err:
        sys.stderr.write("[ERROR] opening %s" % ofile)
        sys.stderr.write(err)
        sys.exit(1)

    space = get_zfs_space(unit)
    for row in space:
        fhandle.write("%s\n" % ",".join(row))

    # Close file
    fhandle.close()

    pprint_table(space)

    print ""
    print "Output saved to %s." % ofile


if __name__ == "__main__":
    main()
