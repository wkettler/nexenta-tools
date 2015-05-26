#!/usr/bin/env python

"""
snap-retention.py

Apply a snapshot retention policy.

Copyright (c) 2015  Nexenta Systems
William Kettler <william.kettler@nexenta.com>
"""

import syslog
import datetime
import subprocess
import signal
import getopt
import sys
import time

# Minimum allowable retention definition
min_retention = 7

# Logger
log_level = "INFO"
syslog.openlog("snap-retention", 0, syslog.LOG_LOCAL0)


def usage():
    """
    Print usage.

    Inputs:
        None
    Outputs:
        None
    """
    cmd = sys.argv[0]

    print "%s [-hfyt] [-p PAUSE] -r DAYS -s SEARCH " % cmd
    print ""
    print "Apply a snapshot retention policy."
    print ""
    print "Arguments:"
    print ""
    print "    -h, --help               Print usage"
    print "    -r, --retention DAYS     Retention policy in days"
    print "    -s, --search SEARCH      Search string will match snapshot"
    print "                             names, e.g. -s AutoSync"
    print "    -f, --force              Force destroy"
    print "    -p, --pause              Time in seconds to sleep between"
    print "                             destroy commands"
    print "    -y, --yes                Automatically answer yes to prompts"
    print "    -t  --test               Test mode"


def logger(level, msg, stdout=True):
    """
    Log messages to stdout and syslog.

    Inputs:
        level   (str): Log level
        msg     (str): Log string
        stdout (bool): Log to syslog
    Outputs:
        None
    """
    levels = {
        "DEBUG": syslog.LOG_DEBUG,
        "INFO": syslog.LOG_INFO,
        "WARN": syslog.LOG_WARNING,
        "ERROR": syslog.LOG_ERR
    }

    if levels[level] <= levels[log_level] and stdout:
        now = str(datetime.datetime.now())
        print "%s [%s] %s" % (now, level, msg)

    syslog.syslog(levels[level], msg)


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


def get_snaps():
    """
    Return a list of ZFS snapshots.

    Inputs:
        None
    Outputs:
        snaps (list): A list of snapshots and creation times
    """
    snaps = []

    cmd = "zfs get -pt snapshot creation"
    try:
        output = execute(cmd)
    except Retcode, r:
        logger("ERROR", str(r))
        logger("ERROR", r.output)
        sys.exit(1)
    except Exception, e:
        logger("ERROR", str(e))
        sys.exit(1)

    for l in output.splitlines()[1:]:
        name, _, creation, _ = l.split()
        snaps.append((name, creation))

    return snaps


def destroy_snap(snap, force=False):
    """
    Destroy a ZFS snapshot.

    Inputs:
        snap   (str): Snapshot name
        force (bool): Force destroy
    Outputs:
        None
    """
    if force:
        cmd = "zfs destroy -f %s" % snap
    else:
        cmd = "zfs destroy %s" % snap

    try:
        execute(cmd)
    except Retcode, r:
        logger("ERROR", str(r))
        logger("ERROR", r.output)
        sys.exit(1)
    except Exception, e:
        logger("ERROR", str(e))
        sys.exit(1)


def main():
    # Initialize arguments
    retention = None
    search = None
    force = False
    yes = False
    test = False
    pause = 0

    # Parse command line arguments
    try:
        opts, args = getopt.getopt(sys.argv[1:], ":hdftyp:r:s:",
                                   ["help", "retention=", "search=", "force",
                                    "yes", "test", "pause="])
    except getopt.GetoptError, err:
        print str(err)
        usage()
        sys.exit(2)

    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-r", "--retention"):
            try:
                retention = int(a)
            except ValueError:
                print "The retention duration must be an integer value."
                sys.exit(1)
            if retention < min_retention:
                print "The min retentiont duration is %s" % min_retention
                sys.exit(1)
        elif o in ("-s", "--search"):
            search = a
        elif o in ("-f", "--force"):
            force = True
        elif o in ("-p", "--pause"):
            try:
                pause = int(a)
            except ValueError:
                print "The pause duration must be an integer value."
                sys.exit(1)
        elif o in ("-y", "--yes"):
            yes = True
        elif o in ("-t", "--test"):
            test = True
        elif o in ("-d"):
            global log_level
            log_level = "DEBUG"
        else:
            print "Unhandled argument."
            usage()
            sys.exit(1)

    # Check required arguments are defined
    if retention is None:
        print "Retention duration required."
        sys.exit(1)
    if search is None:
        print "Search string required."
        sys.exit(1)

    logger("INFO", "STARTING")

    # Log arguments
    logger("INFO", "Argument retention=%s" % retention, stdout=False)
    logger("INFO", "Argument search=%s" % search, stdout=False)
    logger("INFO", "Argument force=%s" % force, stdout=False)
    logger("INFO", "Argument pause=%s" % pause, stdout=False)
    logger("INFO", "Argument yes=%s" % yes, stdout=False)
    logger("INFO", "Argument test=%s" % test, stdout=False)

    # Cutoff date
    cutoff = datetime.datetime.now() - datetime.timedelta(days=retention)

    # Prompt user before continuing due to destructive nature of this script
    logger("INFO", "Snapshots created before %s and matching \"%s\" will be "
           "destroyed" % (cutoff, search))
    if not test and not yes:
        if not prompt_yn("Are you sure you want to continue?"):
            sys.exit(1)

    for snap, creation in get_snaps():
        # Skip syspool snapshots
        if snap.startswith("syspool"):
            logger("DEBUG", "Skipping syspool snapshot %s" % snap)
            continue

        # Skip snapshots that don't containt the search string
        if search is not None and search not in snap:
            logger("DEBUG", "Skipping %s, does not contain search string"
                   % snap)
            continue

        # Skip snapshots that don't meet the retention policy
        if datetime.datetime.fromtimestamp(int(creation)) > cutoff:
            logger("DEBUG", "Skipping %s, does not meet retention policy"
                   % snap)
            continue

        # Destroy the snapshot
        if test:
            logger("INFO", "Destroying %s in test mode" % snap)
        else:
            logger("INFO", "Destroying %s" % snap)
            destroy_snap(snap, force=force)
            logger("INFO", "Sleeping for %s" % pause)
            time.sleep(pause)

    logger("INFO", "FINISHED")


if __name__ == "__main__":
    main()
