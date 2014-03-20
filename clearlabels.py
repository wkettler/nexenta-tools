#!/usr/bin/env python

"""
clearlabels.py

THIS SCRIPT IS NOT INTENDED FOR USE ON A PRODUCTION SYSTEM.

Clear the ZFS label from every drive in the system that is not part of an
imported pool. Drives that are part of an exported pool will formatted and
data will be lost.

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

def format_disk(d):
    """
    Format a drive with an EFI label.

    Inputs:
        d (str): Device ID
    Outputs:
        None
    """
    try:
        retcode, output = execute("fdisk -E /dev/rdsk/%s" % d)
    except:
        raise
    else:
        if retcode:
            sys.stderr.write(output)
            sys.stderr.write("Please review /var/adm/messages for additional "
                             "information.")
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
        sys.stderr.write(str(err))
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
        format_disk(d)


if __name__ == "__main__":
    main()