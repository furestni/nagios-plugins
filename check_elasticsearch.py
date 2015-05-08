#!/usr/bin/python2

import os
import sys
import json
import urllib2
from optparse import OptionParser

__program__ = "check_elasticsearch"
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

  parser.add_option("-s", "--server", dest="servername",
                    action="store", type="string",
                    help="dns name of elaticsearch server",
                    metavar="SERVERNAME")
  parser.add_option("-p", "--port", dest="port",
                    action="store", type="int", default=9200,
                    help="port of elaticsearch server",
                    metavar="PORT")
  return parser

######################################################################
# fetch api
######################################################################
def fetch(url):
    try:
        response = urllib2.urlopen(url).read()
        data = json.loads(response)
    except Exception:
        import traceback
        sys.stdout.write("ERROR: API <a href=\"{0}\" target=\"_blank\">{0}</a> could not be queried".format(url))
        sys.exit(3)
    return data

######################################################################
# check status
######################################################################
def check(health):
    if health["status"] == "green":
        return 0, "All The World Is Green..."
    elif health["status"] == "yellow":
        return 1, "Yellow Submarine..."
    elif health["status"] == "red":
        return 2, "Simply Red..."
    else:
        return 3, "Unknown State: " + health["status"]

######################################################################
# execute
######################################################################
def main():
    parser = getopts()
    (options, args) = parser.parse_args()

    url = "http://" + options.servername + ":" + str(options.port) + "/_cluster/health"
    health = fetch(url)
    (exitcode, out) = check(health)

    sys.stdout.write("<a href=\"{1}\" target=\"_blank\">{0}</a>".format(out, url))
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
