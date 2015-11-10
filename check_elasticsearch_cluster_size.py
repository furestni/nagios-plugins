#!/usr/bin/python2

import os
import sys
import json
import urllib2
from optparse import OptionParser

__program__ = "check_elasticsearch_cluster_size"
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
                    help="dns name of elaticsearch server",
                    metavar="SERVERNAME")
  parser.add_option("-p", "--port", dest="port",
                    action="store", type="int", default=9200,
                    help="port of elaticsearch server",
                    metavar="PORT")
  parser.add_option("-e", "--elasticsearch-id", dest="esid",
                    action="store", type="string", default="elasticsearch",
                    help="substring that identifies the names of the elasticsearch instances in the cluster",
                    metavar="ES_ID")
  parser.add_option("-c", "--elasticsearch-count", dest="escount",
                    action="store", type="int", default=5,
                    help="count of elaticsearch servers",
                    metavar="ES_COUNT")
  parser.add_option("-l", "--logstash-id", dest="lsid",
                    action="store", type="string", default="logstash",
                    help="substring that identifies the names of the logstash instances in the cluster",
                    metavar="LS_ID")
  parser.add_option("-k", "--logstash-count", dest="lscount",
                    action="store", type="int", default=5,
                    help="count of logstash instances",
                    metavar="LS_COUNT")
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
# get logstash instances
######################################################################
def get_instances(nodes, identifier):
    instances = {}
    for node in nodes["nodes"].iteritems():
        if identifier in node[1]["name"]:
            instances[node[1]["name"]] = node[0]
    return instances

######################################################################
# execute
######################################################################
def main():
    parser = getopts()
    (options, args) = parser.parse_args()

    baseurl = "http://" + options.servername + ":" + str(options.port) + "/"

    url = baseurl + "_cluster/state/nodes"
    nodes = fetch(url)

    ls_instances = get_instances(nodes, options.lsid)
    es_instances = get_instances(nodes, options.esid)

    out = ""
    exitcode = 0

    if len(ls_instances) < options.lscount:
        out = "There are logstash instances missing, we only have: " + ", ".join(ls_instances) + ". " + str(options.lscount) + " instances are expected!\n"
        exitcode = 1

    if len(es_instances) < options.escount:
        out = "There are elasticsearch instances missing, we only have: " + ", ".join(es_instances) + ". " + str(options.escount) + " instances are expected!\n"
        exitcode = 1

    if exitcode == 0:
        out = "Enough instances of everything!"

    sys.stdout.write(out)
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
