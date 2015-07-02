#!/usr/bin/env python

"""
clear-labels.py

THIS SCRIPT IS NOT INTENDED FOR USE ON A PRODUCTION SYSTEM.

Clear the ZFS label from every drive in the system that is not part of an
imported pool. Drives that are part of an exported pool will formatted and
data will be lost.

Copyright (C) 2015  Nexenta Systems
William Kettler <william.kettler@nexenta.com>
"""

import re
import subprocess
import getopt
import sys
import signal
import time


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


class Signal(Exception):
    """
    This exception is raise by the signal handler.
    """
    pass


class Timeout(Exception):
    """
    This exception is raised when the command exceeds the defined timeout
    duration and the command is killed.
    """
    def __init__(self, cmd, timeout):
        self.cmd = cmd
        self.timeout = timeout

    def __str__(self):
        return "Command '%s' timed out after %d second(s)." % \
               (self.cmd, self.timeout)


class Retcode(Exception):
    """
    This exception is raise when a command exits with a non-zero exit status.
    """
    def __init__(self, cmd, retcode, output=None):
        self.cmd = cmd
        self.retcode = retcode
        self.output = output

    def __str__(self):
        return "Command '%s' returned non-zero exit status %d" % \
               (self.cmd, self.retcode)


def alarm_handler(signum, frame):
    raise Signal


def execute(cmd, timeout=None):
    """
    Execute a command in the default shell. If a timeout is defined the command
    will be killed if the timeout is exceeded and an exception will be raised.

    Inputs:
        cmd     (str): Command to execute
        timeout (int): Command timeout in seconds
    Outputs:
        output (str): STDOUT/STDERR
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
        output, _ = phandle.communicate()
        retcode = phandle.poll()
    except Signal:
        # Kill the running process
        phandle.kill()
        raise Timeout(cmd=cmd, timeout=timeout)
    except:
        logger.debug("Unhandled exception", exc_info=True)
        raise
    else:
        # Possible race condition where alarm isn't disabled in time
        signal.alarm(0)

    # Raise an exception if the command exited with non-zero exit status
    if retcode:
        raise Retcode(cmd, retcode, output=output)

    return output


def format_disks(disks):
    """
    Format a drives. The easiest way to do this is to create/destroy a zpool
    on all the drives.

    Inputs:
        disks (list): A list of device IDs
    Outputs:
        None
    """
    print "Formatting devices, please be patient..."
    # Create the pool
    try:
        output = execute("zpool create -f clear %s" % " ".join(disks))
    except Retcode, r:
        sys.stderr.write(str(r))
        sys.stderr.write(r.output)
        sys.stderr.write("Please review /var/adm/messages for additional "
                         "information.\n")
        sys.exit(1)

    # Destroy the pool
    while True:
        try:
            output = execute("zpool destroy clear")
        except Retcode:
            # Zpool destroy may fail with device busy immediately after
            # creating a pool. We will retry until it succeeds.
            time.sleep(30)
            continue
        else:
            break

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
        output = execute(cmd)
    except Retcode, r:
        if r.retcode != 1:
            sys.stderr.write(str(r))
            sys.stderr.write(r.output)
            sys.exit(1)
        else:
            output = r.output

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
        output = execute(cmd)
    except Retcode, r:
        sys.stderr.write(str(r))
        sys.stderr.write(r.output)
        sys.exit(1)

    for line in output.splitlines():
        if re.search(r'(c[0-9]+t.*d[0-9]+)', line):
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
    wipe = []
    for d in disks:
        # If the disk is part of a pool continue
        if any(d in z for z in zpool_disks):
            continue

        # Add the disk to the wipe list
        wipe.append(d)

    format_disks(wipe)

if __name__ == "__main__":
    main()
