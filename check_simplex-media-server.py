#!/usr/bin/python2

import os
import sys
import json
import urllib2
from optparse import OptionParser

__program__ = "check_simplex-media-check"
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

  usg = "{0} [options]".format(program)
  parser = OptionParser(usage=usg)

  parser.add_option("-s", "--server", dest="servername",
                    action="store", type="string",
                    help="dns name or ip address of simplex media server",
                    metavar="SERVERNAME")
  parser.add_option("-p", "--port", dest="port",
                    action="store", type="int", default=9200,
                    help="port of simplex media server",
                    metavar="PORT")
  return parser

######################################################################
# fetch api
######################################################################
def fetch(url):
    try:
        response = urllib2.urlopen(url).read()
    except Exception:
        import traceback
        sys.stdout.write("ERROR: API <a href=\"{0}\" target=\"_blank\">{0}</a> could not be queried".format(url))
        sys.exit(3)
    return response

######################################################################
# parse keys, values
######################################################################
def parse(data):
    pairs = {}
    lines = data.split("\n")
    for line in lines:
        kv = line.split("=")
        if len(kv) == 2:
            pairs[kv[0].strip().lower()] = kv[1].strip()
    return pairs

######################################################################
# check status
######################################################################
def check(health):
    if health["zulu"] == "happy":
        return 0, "Zulu is happy"
    elif health["zulu"] == "sad":
        return 2, "Zulu is sad"
    else:
        return 3, "Zulu does not know about the meaning of his feelings: " + health["zulu"]

######################################################################
# interpret infos
######################################################################
def interpret(health):
    out = "<table border='0'>"

    meaning = {
        'alfa': 'Milliseconds to Write and Delete a File',
        'beta': 'Concurrent Content Requests',
        'charlie': '# of Files Being Sent to Clients',
        'delta': 'Not Defined',
        'echo': 'Server Name',
        'foxtrot': 'Server Version',
        'golf': 'HTTP Header "X-forwarded-for"',
        'hotel': 'Build Number',
        'indigo': 'Last File Upload',
        'juliet': 'Server Uptime',
        'kilo': 'HTTP Header "Via"',
        'lima': 'Local IP Address',
        'mike': 'Not Defined',
        'nancy': 'Server Time',
        'oscar': 'Not Defined',
        'papa': 'DB Access',
        'quebec': 'Lighttpd Status',
        'romeo': 'Compatibility Mode',
        'zulu': 'Allover Health Status',
    }

    for i in health:
        out += "<tr style='border-bottom:1px solid #000'><td>" + meaning[i] + " (" + i + ")</td><td>" + health[i] + "</td></tr>"

    out += "</table>"
    return out

######################################################################
# execute
######################################################################
def main():
    parser = getopts()
    (options, args) = parser.parse_args()

    url = "http://" + options.servername + ":" + str(options.port) + "/AliceAndBob"
    aliceandbob = fetch(url)
    health = parse(aliceandbob)
    (exitcode, out) = check(health)
    info = interpret(health)

    sys.stdout.write("<b><a href=\"{1}\" target=\"_blank\">{0}</a></b><br>{2}".format(out, url, info))
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
