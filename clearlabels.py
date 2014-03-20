#!/usr/bin/env python

"""
clearlabels.py

THIS SCRIPT IS NOT INTENDED FOR USE ON A PRODUCTION SYSTEM.

Clear the ZFS label from every drive in the system that is not part of an
imported pool. Drives that are part of an exported pool will be overwritten
and data will be lost.

Copyright (C) 2014  Nexenta Systems
William Kettler <william.kettler@nexenta.com>
"""

import re
import subprocess
import getopt
import sys


def usage():
    """
    Print usage.

    Inputs:
        None
    Outputs:
        None
    """
    cmd = sys.argv[0]

    print "%s -r [-h] [-o OPTION]" % cmd
    print ""
    print "Clear the ZFS label from every drive in the system that is not " \
          "part of an active pool."
    print ""
    print "Arguments:"
    print ""
    print "    -h, --help           print usage"
    print "    -f, --force          do not prompt user"


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
        output = stdout.strip()
    else:
        output = None

    return retcode, output


def dd(ifile, ofile, bs, count=None, seek=None):
    """
    Wrapper for the GNU dd command.

    Inputs:
        ifile (str): Input file
        ofile (str): Output file
        bs    (str): Block size
        count (int): Number of blocks to copy
        seek  (int): Skip x blocks
    Outputs:
        None
    """
    # Execute dd command
    cmd = "dd if=%s of=%s bs=%s" % (ifile, ofile, bs)
    if count is not None:
        cmd = " ".join([cmd, "count=%s" % count])
    if seek is not None:
        cmd = " ".join([cmd, "seek=%s" % seek])

    try:
        retcode, output = execute(cmd)
    except:
        raise
    else:
        if retcode:
            sys.stderr.write(output)
            sys.exit(1)


def get_disks():
    """
    Return all device IDs.

    Inputs:
        None
    Outputs:
        disks (list): Disks
    """
    disks = []
    cmd = "format </dev/null"

    try:
        retcode, output = execute(cmd)
    except:
        raise
    else:
        if retcode != 0 and retcode != 1:
            sys.stderr.write(output)
            sys.exit(1)

    for line in output.splitlines():
        if re.search(r'(c[0-9]t.*d[0-9])', line):
            disks.append(line.split()[1])

    return disks


def get_sector_count(d):
    """
    Return the sector count of partition 0.

    Inputs:
        d (str): Device ID
    Outputs:
        part    (int): Partition number
        sectors (int): Sector count
    """
    cmd = "prtvtoc -sh /dev/rdsk/%sp0" % d

    try:
        retcode, output = execute(cmd)
    except:
        raise
    else:
        if retcode:
            sys.stderr.write(output)
            sys.stderr.write("Please check /var/adm/messages for errors.")
            sys.exit(1)

    sectors = int(output.splitlines()[0].split()[4])

    return sectors


def get_zpool_disks():
    """
    Return all device IDs part of an active zpool.

    Inputs:
        None
    Outputs:
        disks (list): Disks
    """
    disks = []
    cmd = "zpool status"

    try:
        retcode, output = execute(cmd)
    except:
        raise
    else:
        if retcode:
            sys.stderr.write(output)
            sys.exit(1)

    for line in output.splitlines():
        if re.search(r'(c[0-9]t.*d[0-9])', line):
            disks.append(line.split()[0])

    return disks


def clear_labels(d):
    """
    Clear ZFS device labels written to the first and last 512KB of the disk.

    Inputs:
        d (str): Device ID
    Outputs:
        None
    """
    sectors = get_sector_count(d)
    path = '/dev/dsk/%sp0' % d

    # Write zeroes to the first 512KB of the drive
    dd('/dev/zero', path, 512, count=1024, seek=None)

    # Write zeroes to the last 512KB of the drive
    # Each sector is 512B and we want to overwrite the last 512KB
    seek = sectors - 1024
    dd('/dev/zero', path, 512, count=1024, seek=seek)


def prompt_yn(question):
    """
    Prompt the user with a yes or no question.

    Input:
        question (str): Question string
    Output:
        answer (bool): Answer True/False
    """
    while True:
        choice = raw_input("%s [y|n] " % question)
        if choice == "y":
            answer = True
            break
        elif choice == "n":
            answer = False
            break
        else:
            print "Invalid input."

    return answer


def main():
    # Parse command line arguments
    try:
        opts, args = getopt.getopt(sys.argv[1:], ":hf", ["help", "force"])
    except getopt.GetoptError, err:
        print str(err)
        usage()
        sys.exit(2)

    # Initialize arguments
    force = False

    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-f", "--force"):
            force = True

    # Prompt user before continuing.
    print "THIS SCRIPT IS NOT INTENDED FOR USE ON A PRODUCTION SYSTEM. " \
          "THIS SCRIPT IS INTENDED FOR TEST ENVIRONMENTS ONLY. DATA " \
          "LOSS IS IMMINENT."
    if not force:
        if not prompt_yn('Disk labels are about to be removed, continue?'):
            sys.exit(1)
        if not prompt_yn('Are you sure?'):
            sys.exit(1)

    disks = get_disks()
    zpool_disks = get_zpool_disks()

    # Iterate over all disks
    for d in disks:
        # If the disk is part of a pool continue
        if any(d in z for z in zpool_disks):
            continue

        print '* Clearing %s labels.' % d
        clear_labels(d)


if __name__ == "__main__":
    main()