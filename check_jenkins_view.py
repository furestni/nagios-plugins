#!/usr/bin/python2

import os
import sys
import json
import urllib2
from optparse import OptionParser

__program__ = "check_jenkins_view"
__version__ = "0.1"

######################################################################
# print version
######################################################################
def version():
    p = "{0} v{1}\n".format(__program__, __version__)
    sys.stdout.write(p)

######################################################################
# read opts
######################################################################
def getopts():
  program = os.path.basename(sys.argv[0])

  usg = "{0} -h | -b | -v | -c | -w".format(program)
  parser = OptionParser(usage=usg)

  parser.add_option("-b", "--baseurl", dest="baseurl",
                    action="store", type="string",
                    help="the base url of jenkins server",
                    metavar="BASEURL")
  parser.add_option("-v", "--view", dest="view",
                    action="store", type="string",
                    help="the view you want to monitor",
                    metavar="VIEW")
  parser.add_option("-c", "--critical", dest="critical",
                    default="", action="store", type="string",
                    help="a comma-separated list of build colors that should be alarmed as critical",
                    metavar="CRITCAL")
  parser.add_option("-w", "--warn", dest="warn",
                    default="", action="store", type="string",
                    help="a comma-separated list of build colors that should be alarmed as warning",
                    metavar="WARN")
  return parser

######################################################################
# fetch view
######################################################################
def fetchview(baseurl, view):
    try:
        url = baseurl + "/view/" + view + "/api/json"
        response = urllib2.urlopen(url).read()
        data = json.loads(response)
    except Exception:
        import traceback
        sys.stdout.write('ERROR: API could not be queried')
        sys.exit(3)
    return data

######################################################################
# check view
######################################################################
def checkview(view, alarm):
    alarmstates = alarm.split(",")
    if "green" in alarmstates:
        alarmstates.append("blue")

    failed = []
    for job in view["jobs"]:
        for state in alarmstates:
            if job["color"] == state:
                failed.append(job["name"])

    return failed

######################################################################
# execute
######################################################################
def main():
    parser = getopts()
    (options, args) = parser.parse_args()

    viewdata = fetchview(options.baseurl, options.view)

    critical = checkview(viewdata, options.critical)
    warn = checkview(viewdata, options.warn)

    exitcode = 0
    out = []

    if len(warn) > 0:
        jobs = ', '.join(str(job) for job in warn)
        out.append("These jobs are in a WARN state: {0}".format(jobs))
        exitcode = 1

    if len(critical) > 0:
        jobs = ', '.join(str(job) for job in critical)
        out.append("These jobs are in a CRITICAL state: {0}".format(jobs))
        exitcode = 2

    if exitcode == 0:
        out = ["All jobs match the required state"]

    sys.stdout.write(' / '.join(str(job) for job in out))
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
