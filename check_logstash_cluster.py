#!/usr/bin/python2

import os
import sys
import json
import urllib2
from optparse import OptionParser

__program__ = "check_logstash_cluster"

STATUS_OK = 0
STATUS_WARNING = 1
STATUS_CRITICAL = 2
STATUS_UNKNOWN = 3

###############################################################################
# Command Options
###############################################################################

def getopts():
  program = os.path.basename(sys.argv[0])

  usage = "{0} [options]".format(program)
  parser = OptionParser(usage=usage)

  parser.add_option("-s", "--server",
                    dest = "servername",
                    action = "store",
                    type = "string",
                    help = "X-Pack monitoring Elasticsearch address",
                    metavar = "SERVERNAME")
  parser.add_option("-p", "--port",
                    dest = "port",
                    action = "store",
                    type = "int",
                    default = 9200,
                    help = "X-Pack monitoring Elasticsearch port",
                    metavar = "PORT")
  parser.add_option("-c", "--minimum-count",
                    dest = "minimum_count",
                    action = "store",
                    type = "int",
                    default = 4,
                    help = "Expected count of active Logstash instances",
                    metavar = "MINIMUM_COUNT")
  parser.add_option("-t", "--time-period",
                    dest = "time_period",
                    action = "store",
                    type = "int",
                    default = 1,
                    help = "The amount of time (in minutes) since now, where Logstash activity is considered",
                    metavar = "TIME_PERIOD")

  return parser


###############################################################################
# Search in X-Packing Logstash Monitoring Indices
###############################################################################

def get_logstash_cluster_status(baseurl, time_period):

    url = baseurl + ".monitoring-logstash-*/_search"

    try:
        req_data =  """
                        {
                            "query": {
                                "constant_score" : {
                                    "filter" : { "range": { "timestamp" : { "gt" : "now-%dm" }  }  }
                                }
                            },
                            "_source": [
                                "logstash_stats.logstash.host",
                                "logstash_stats.logstash.status"
                            ],
                            "from" : 0,
                            "size" : 100,
                            "sort" : [ { "timestamp" : "desc" } ]
                        }
                    """ % (time_period)

        response = urllib2.urlopen(url, req_data).read()
        data = json.loads(response)

    except Exception as e:
        import traceback
        sys.stdout.write("ERROR in Elasticsearch API request: {}\n".format(e))
        sys.exit(STATUS_UNKNOWN)


    ls_instances = get_last_status(data)
    green_count = sum([1 for x in ls_instances.values() if x == 'green'])

    return ls_instances, green_count

def get_last_status(logstash_stats):
    instances = {}

    for hit in logstash_stats["hits"]["hits"]:
        ls_node = hit["_source"]["logstash_stats"]["logstash"]

        if ls_node["host"] not in instances.keys():
            instances[ls_node["host"]] = ls_node["status"]

    return instances


###############################################################################
# Helpers
###############################################################################

def print_cluster_status(cluster):
    if not cluster:
        return "empty"

    return ", ".join('{}[{}]'.format(k,v) for k,v in sorted(cluster.iteritems()))


###############################################################################
# Command Main function
###############################################################################

def main():
    out = ""
    exitcode = STATUS_UNKNOWN

    parser = getopts()
    (options, args) = parser.parse_args()

    baseurl = "http://{:s}:{:d}/".format(options.servername, options.port)

    ls_instances, ok_count = get_logstash_cluster_status(baseurl, options.time_period)

    gap = options.minimum_count - ok_count
    if gap <= 0:
        exitcode = STATUS_OK
        out = "Enough active instances: {} ({})".format(ok_count, print_cluster_status(ls_instances))
    else:
        if gap == 1:
            # One node can temporarily fail (e.g. during a deployment rollout)
            exitcode = STATUS_WARNING
        else:
            exitcode = STATUS_CRITICAL
        out = "NOT enough active instances: {} ({})".format(ok_count, print_cluster_status(ls_instances))

    ## Performance indicators: 'label'=value[UOM];[warn];[crit];[min];[max]
    perf_data = " | active={ok};{warn};{crit};0;".format(ok=ok_count, warn=options.minimum_count-1, crit=options.minimum_count-2)

    sys.stdout.write(out + perf_data + "\n")
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
