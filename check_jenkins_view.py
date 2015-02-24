#!/usr/bin/python2

import os
import sys
import json
import urllib2
from pprint import pprint
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

  usg = "{0} -h | -b | -v | -a".format(program)
  parser = OptionParser(usage=usg)

  parser.add_option("-b", "--baseurl", dest="baseurl",
                    action="store", type="string",
                    help="the base url of jenkins server",
                    metavar="BASEURL")
  parser.add_option("-v", "--view", dest="view",
                    action="store", type="string",
                    help="the view you want to monitor",
                    metavar="VIEW")
  parser.add_option("-a", "--alarm", dest="alarmstates",
                    default="red,yellow", action="store", type="string",
                    help="a comma-separated list of build colors that should be alarmed",
                    metavar="ALARM")
  return parser

######################################################################
# fetch jobs from view
######################################################################
def checkview(baseurl, view, alarm):
    alarmstates = alarm.split(",")
    if "green" in alarmstates:
        alarmstates.append("blue")

    try:
        url = baseurl + "/view/" + view + "/api/json"
    except Exception:
        import traceback
        sys.stdout.write('ERROR: API could not be queried\n')
        sys.exit(3)

    response = urllib2.urlopen(url).read()
    data = json.loads(response)

    failed = []
    for job in data["jobs"]:
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

    failed = checkview(options.baseurl, options.view, options.alarmstates)

    if len(failed) > 0:
        joblist = ', '.join(str(job) for job in failed)
        sys.stdout.write("These jobs do not match the required state: {0}\n".format(joblist))
        sys.exit(2)
    else:
        sys.stdout.write("All jobs match the required state\n")
        sys.exit(0)

if __name__ == "__main__":
    main()
