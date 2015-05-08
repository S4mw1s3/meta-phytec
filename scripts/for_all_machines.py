#!/usr/bin/env python2
# -*- coding: utf-8 -*-
#
# Copyright (C) 2015 PHYTEC Messtechnik GmbH,
# Author: Stefan Christ <s.christ@phytec.de>

import sys
import os
import signal
import re
from subprocess import Popen, PIPE

sys.path.append(os.path.dirname(os.path.realpath(__file__)))
from phylib import Sourcecode

# TODO Maybe read machines from stdin. Useful for releasing only a subset of
# machines.

# Name of program. Used for prefix stderr output.
name = "for_all_machines"


# TODO Is there a python library function for this mapping?
signal_to_str = {signal.SIGTERM: "SIGTERM",
                 signal.SIGINT: "SIGINT"
                 }

# Global variables for signal handlers. There is no nicer way to do this.
# Signal handlers are global for the process.
p = None
exit_app = False


def signal_handler(signum, frame):
    global p, exit_app
    if p is None:
        print >>sys.stderr, \
            "%s: No process to send signal %s. Program will abort!" % \
            (name, signal_to_str[signum])
    else:
        print >>sys.stderr, \
            "%s: Send signal %s to process with pid %d. Program will abort!" % \
            (name, signal_to_str[signum], p.pid)
        p.send_signal(signum)
    exit_app = True


# NOTE: command in cmd must not be a bitbake call. It maybe any shell command.
def call_bitbake(env, machine, prefix, cmd):
    global p

    env["MACHINE"] = machine

    p = Popen(cmd, shell=True, env=env, stdout=PIPE)

    while p.poll() is None:
        # FIXME use select() to wait for data
        while True:
            line = p.stdout.readline()
            # '' means: EOF reached
            if line == '':
                break
            # FIXME Is line ending correct in all cases?
            print "%s: %s" % (prefix, line),

    # stdout is closed, check for process termination
    p.wait()
    # TODO Is this needed? merge with code from above.
    for line in p.stdout.readlines():
        print "%s: %s" % (prefix, line),

    ret = p.returncode

    # Set global variable p to None, so signal_handler doesn't send
    # a signal to a non-existing process.
    p = None

    return ret


def for_all_machines(machines, cmd):
    global exit_app

    # Make a copy of current process enviroment to modify it for subprocess
    env = dict(os.environ)

    non_build_machines = set(machines)

    ret = 0  # default exit code if machines are empty.
    for i, machine in enumerate(machines, 1):
        prefix = "%s (%d/%d)" % (machine, i, len(machines))

        ret = call_bitbake(env, machine, prefix, cmd)

        if ret != 0:
            # Only print exit code for program if it is non zero.
            print >>sys.stderr, "%s: exit code of program is %d" % (name, ret)
            # shell function has a non successful exit_code
            # abort the for_each_loop
            break

        # build was successful
        non_build_machines.remove(machine)

        if exit_app:
            # A signal was received. Abort for_all_machines!
            break

    return ret, non_build_machines


# Quick and dirty commandline parsing. Maybe use module argparse instead.
def parse_args(args):
    if "--" in args:
        i = args.index("--")
        machines = args[:i]
        cmd = args[i + 1:]
    else:
        # Use all machines
        machines = None
        cmd = args
    return cmd, machines


def print_usage():
    name = sys.argv[0]
    print """Usage: %s [cmd]*   or   %s [machine]* -- [cmd]*

 [cmd]*      bitbake or shell command to execute
 [machine]*  one or more machines to use

Calls bitbake or any shell command and sets the appropriated $MACHINE
environment variable. If only a command is provided, all machines are used.

You can use CTRL+C to abort the execution and CTRL+Z to suspend it (use 'fg' to
continue). See DOCUMENTATION.md.

Examples:
  Get barebox version of every machine:
    ../tools/for_all_machines "bitbake -s | grep barebox"
  Build the kernel:
    ../tools/for_all_machines bitbake virtual/kernel
  Build image for two machines:
    ../tools/for_all_machines phyflex-imx6-1 phyboard-wega-am335x-1 -- bitbake phytec-hwbringup-image

""" % (name, name),


def sanity_checks():
    # Sanity check: Are we in a bitbake environment?
    if "BUILDDIR" not in os.environ or not os.path.isdir(os.environ["BUILDDIR"]):
        print >>sys.stderr, "Environment variable $BUILDIR not found or is not a directory!\n" \
            "You have to execute \"source sources/poky/oe-init-build-env\" first."
        return 1

    # Sanity check: Is "MACHINE ?=" in local.conf?
    content = None
    try:
        with open(os.path.join(os.environ["BUILDDIR"], "conf", "local.conf")) as f:
            content = f.read()
    except IOError as e:
        print >>sys.stderr, "Cannot read conf/local.conf. Sanity check failed!"
        # Sanity check has failed, but continue

    if content is not None and re.search(r"^\s*MACHINE\s*=", content, flags=re.M):
        print >>sys.stderr, "The file conf/local.conf contains a \"MACHINE = …\" assigment.\n" \
            "You have to use \"MACHINE ?= …\". Otherwise a environment variable cannot overwrite it."
        return 1
    return 0


def main():
    global exit_app

    if len(sys.argv) == 1:
        print_usage()
        sys.exit(0)

    # Parse commandline arguments
    cmd_list, machines = parse_args(sys.argv[1:])  # remove name of program
    if machines is None:
        # Use all machines
        # Get all machines from sources/meta-phytec/meta-phy*/conf/machine/
        sourcecode = Sourcecode()
        # sourcecode.machines is a Vividict which is nearly a normal
        # dict. We only need the machines as a list of strings.
        machines = sourcecode.machines.keys()
    cmd = " ".join(cmd_list)

    # Sanity checks
    ret = sanity_checks()
    if ret != 0:
        sys.exit(ret)

    # Register signal handlers to forward signals to the python process
    # to the bitbake process
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    machines.sort()  # sort machines to be deterministic

    # Execute command
    print >>sys.stderr, "%s: cmd is \"%s\"" % (name, cmd)
    ret, non_build_machines = for_all_machines(machines, cmd)

    if len(non_build_machines):
        # Usability feature: Print commandline to reexecute for_all_machines call
        # TODO Shell escaping for string in cmd
        print
        print "To restart the build process with all unbuild machines, execute:"
        print "%s %s -- \"%s\"" % \
            (sys.argv[0], " ".join(sorted(non_build_machines)), cmd)

    # Use the return code of the last bitbake call
    sys.exit(ret)


if __name__ == "__main__":
    main()
