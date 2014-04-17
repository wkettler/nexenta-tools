#!/usr/bin/env python

"""
clearpgr3.py

RUNNING THIS SCRIPT ON A PRODUCTION SYSTEM CAN BE DANGEROUS AND LEAD TO SERVICE
OUTAGES OR DATA LOSS.

Clear PGR3 reservations from every drive in the system that is not part of an
active pool.

Copyright (c) 2014  Nexenta Systems
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
    print "Clear PGR3 reservations from every drive in the system that is " \
          "not part of an active pool."
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
        if re.search(r'(c[0-9]+t.*d[0-9]+)', line):
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


def release_pgr3(d):
    """
    Release PGR3 reservation from drive.

    Inputs:
        d (str): Device ID
    Outputs:
        None
    """
    cmd = "/opt/HAC/RSF-1/bin/mhdc -v -d /dev/rdsk/%ss0 -c PGR3_RELEASE" % d

    try:
        retcode, output = execute(cmd)
    except:
        raise

    # Print output
    if output and output is not None:
        print output


def take_pgr3(d):
    """
    Take ownership of the PGR3 reservation.

    Inputs:
        d (str): Drive ID
    Outputs:
        None
    """
    cmd = "/opt/HAC/RSF-1/bin/mhdc -v -d /dev/rdsk/%ss0 -c PGR3_TAKE" % d

    try:
        retcode, output = execute(cmd)
    except:
        raise

    # Print output
    if output and output is not None:
        print output


def disable_failfast(d):
    """
    Disable RSF failfast.

    Inputs:
        d (str): Drive ID
    Outputs:
        None
    """
    cmd = "/opt/HAC/RSF-1/bin/mhdc -v -d /dev/rdsk/%ss0 -c ENFAILFAST 0" % d

    try:
        retcode, output = execute(cmd)
    except:
        raise

    # Print output
    if output and output is not None:
        print output


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
    print "RUNNING THIS SCRIPT ON A PRODUCTION SYSTEM CAN BE DANGEROUS AND " \
          " LEAD TO SERVICE OUTAGES OR DATA LOSS."
    if not force:
        if not prompt_yn('PGR3 reservations are about to be removed, '
                         'continue?'):
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

        print '* Clearing %s PGR3 reservation.' % d
        disable_failfast(d)
        take_pgr3(d)
        release_pgr3(d)


if __name__ == "__main__":
    main()