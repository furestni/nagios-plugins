#!/usr/bin/python2

import os
import sys
import json
import urllib2
from optparse import OptionParser


__program__ = "check_elasticsearch_cluster_size"


STATUS_OK = 0
STATUS_WARNING = 1
STATUS_CRITICAL = 2
STATUS_UNKNOWN = 3


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
  parser.add_option("-c", "--minimum-count", dest="minimum_count",
                    action="store", type="int", default=4,
                    help="Expected count of active Elasticsearch instances",
                    metavar="MINIMUM_COUNT")

  return parser


def get_elasticsearch_instances(baseurl):
    url = baseurl + "_cluster/state/nodes"
    try:
        response = urllib2.urlopen(url).read()
        data = json.loads(response)
    except Exception:
        import traceback
        sys.stdout.write("ERROR: API <a href=\"{0}\" target=\"_blank\">{0}</a> could not be queried".format(url))
        sys.exit(STATUS_UNKNOWN)

    instances = []
    for node in data["nodes"].iteritems():
        instances.append(node[1]["name"])

    return sorted(instances)


def main():
    out = ""
    exitcode = STATUS_UNKNOWN

    parser = getopts()
    (options, args) = parser.parse_args()

    baseurl = "http://" + options.servername + ":" + str(options.port) + "/"
    es_instances = get_elasticsearch_instances(baseurl)
    es_count = len(es_instances)

    gap = options.minimum_count - es_count
    if gap <= 0:
        exitcode = STATUS_OK
        out = "Enough active instances: {} ({})".format(es_count, ", ".join(es_instances))
    else:
        if gap == 1:
            # One node can temporarily fail (e.g. during a deployment rollout)
            exitcode = STATUS_WARNING
        else:
            exitcode = STATUS_CRITICAL
        out = "NOT enough active instances: {} ({})".format(es_count, ", ".join(es_instances))

    ## Performance indicators: 'label'=value[UOM];[warn];[crit];[min];[max]
    perf_data = " | active={ok};{warn};{crit};0;".format(ok=es_count, warn=options.minimum_count-1, crit=options.minimum_count-2)

    sys.stdout.write(out + perf_data + "\n")
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
