#!/usr/bin/python2

import argparse
import base64
import json
import os
import re
import sys
import urllib2

__program__ = "check_couchbase_cluster"


STATUS_OK = 0
STATUS_WARNING = 1
STATUS_CRITICAL = 2
STATUS_UNKNOWN = 3


def get_argument_parser():

  program = os.path.basename(sys.argv[0])

  parser = argparse.ArgumentParser(description = "Verify Couchbase Cluster Health")

  parser.add_argument(  "-s", "--server",
                        required= True,
                        dest = "host",
                        action = "store",
                        help = "Couchbase Node Address")
  parser.add_argument(  "-p", "--port",
                        required= False,
                        dest = "port",
                        action = "store",
                        type = int,
                        default = 8091,
                        help = "Couchbase Node Web Admin port")
  parser.add_argument(  "-U", "--username",
                        required= True,
                        dest = "username",
                        action = "store",
                        help = "Couchbase User Password")
  parser.add_argument(  "-P", "--password",
                        required= True,
                        dest = "password",
                        action = "store",
                        help = "Couchbase Admin Password")

  parser.add_argument(  "-n", "--cluster-size",
                        required= True,
                        dest = "cluster_size",
                        action = "store",
                        type = int,
                        help = "Expected number of nodes")

  return parser


def get_couchbase_health_data(baseurl, username, password):

    url = baseurl + "/pools/nodes"
    request = urllib2.Request(url)

    request.add_header("Authorization", "Basic %s" % base64.encodestring('%s:%s' % (username, password)).replace('\n', ''))
    try:
        response = urllib2.urlopen(request).read()
        data = json.loads(response)
    except Exception:
        import traceback
        sys.stdout.write("ERROR with request to {0}\n".format(url))
        sys.exit(STATUS_UNKNOWN)

    efficient_nodes_count = len(filter(lambda n : n["clusterMembership"] == "active" and n["status"] == "healthy", data["nodes"]))

    this_node = None
    perf_data = {
        "active_items" : 0,
        "replica_items" : 0,
    }
    for n in data["nodes"]:
        if "thisNode" in n:
            this_node = n
            if "interestingStats" in n and len(n["interestingStats" ]) > 0:
                perf_data["active_items"] = n["interestingStats"]["curr_items"]
                perf_data["replica_items"] = n["interestingStats"]["vb_replica_curr_items"]

    # All nodes must be both "healthy" and "active"
    return efficient_nodes_count == len(data["nodes"]), efficient_nodes_count, data["rebalanceStatus"], this_node, perf_data


def main():

    errors = []
    exitcode = STATUS_OK

    args = get_argument_parser().parse_args()

    baseurl = "http://{:s}:{:d}".format(args.host, args.port)


    (cluster_is_healthy, efficient_nodes_count, rebalance_status, this_node, perf_data) = get_couchbase_health_data(baseurl, args.username, args.password)

    if rebalance_status == "running":
        errors.append("Rebalance in progress")
        exitcode = STATUS_WARNING

    if efficient_nodes_count < args.cluster_size:
        errors.append("Only {} efficient node(s) instead of the {} expected".format(efficient_nodes_count, args.cluster_size))
        exitcode = STATUS_WARNING

    if not cluster_is_healthy:
        errors.append("Cluster is NOT healthy".format(efficient_nodes_count, args.cluster_size))
        exitcode = STATUS_CRITICAL


    # Performance indicators: 'label'=value[UOM];[warn];[crit];[min];[max]
    perf_data_text = " | efficient_nodes={};;{};0;".format(efficient_nodes_count, args.cluster_size-1)
    for k, v in sorted(perf_data.iteritems()):
        perf_data_text += " {}={};;;0;".format(k, v)

    node_text = "Node is {} and {}. ".format(this_node["status"], this_node["clusterMembership"])

    cluster_text = ""
    if exitcode != STATUS_OK:
        cluster_text = ". ".join(reversed(errors))
    else:
        cluster_text = "Cluster looks good!"

    sys.stdout.write(node_text + cluster_text + perf_data_text + "\n")
    sys.exit(exitcode)


if __name__ == "__main__":
    main()
