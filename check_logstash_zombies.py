#!/usr/bin/python2

import os
import sys
import json
import urllib2
from optparse import OptionParser

__program__ = "check_logtash_zombies"
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

  usg = "{0} -h | -s | -p  | -i | -b ".format(program)
  parser = OptionParser(usage=usg)

  parser.add_option("-s", "--server", dest="servername",
                    action="store", type="string",
                    help="dns name of elaticsearch server",
                    metavar="SERVERNAME")
  parser.add_option("-p", "--port", dest="port",
                    action="store", type="int", default=9200,
                    help="port of elaticsearch server",
                    metavar="PORT")
  parser.add_option("-i", "--identifier", dest="identifier",
                    action="store", type="string", default="logstash",
                    help="substring that identifies the names of the logstash instances in the cluster",
                    metavar="GLOB")
  parser.add_option("-b", "--heartbeat", dest="heartbeat",
                    action="store", type="int", default=120,
                    help="maximum interval of the logstash heartbeat",
                    metavar="HEARTBEAT")
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
def get_logstash_instances(nodes, identifier):
    logstash_instances = {}
    for node in nodes["nodes"].iteritems():
        if identifier in node[1]["name"]:
            logstash_instances[node[0]] = node[1]["name"]
    return logstash_instances

######################################################################
# check if logstash instances sends heartbeat
######################################################################
def is_zombie(result):
    if result["hits"]["total"] > 0:
        return False
    return True


######################################################################
# execute
######################################################################
def main():
    parser = getopts()
    (options, args) = parser.parse_args()

    baseurl = "http://" + options.servername + ":" + str(options.port) + "/"

    url = baseurl + "_cluster/state/nodes"
    nodes = fetch(url)
    logstash_instances = get_logstash_instances(nodes, options.identifier)

    url = baseurl + "logstash-*/heartbeat/_search?q="
    zombies = []
    for node_name in logstash_instances.itervalues():
        query = "+type: heartbeat +shipped_by.raw:{0} +@timestamp:>now-{1}s".format(node_name, options.heartbeat)
        query = urllib2.quote(query)
        result = fetch(url + query)
        if is_zombie(result):
            zombies.append(node_name)

    if len(zombies) > 0 :
        out = "The following logstash instances do not have a heartbeat and are therefore zombies: " + ", ".join(zombies) 
        exitcode = 2
    else:
        out = "All instances are alive and well"
        exitcode = 0

    sys.stdout.write(out)
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
