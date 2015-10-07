#!/usr/bin/python2

import os
import sys
import json
import urllib2
from optparse import OptionParser

__program__ = "check_pcache_hit-miss-ratio.py"
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

  parser.add_option("-e", "--elastic", dest="servername",
                    action="store", type="string",
                    help="dns name of elaticsearch server",
                    metavar="SERVERNAME")
  parser.add_option("-p", "--port", dest="port",
                    action="store", type="int", default=9200,
                    help="port of elaticsearch server",
                    metavar="PORT")
  parser.add_option("-v", "--volumekey", dest="volumekey",
                    action="store", type="string", default="",
                    help="volume_key that needs to be checked",
                    metavar="VOLUMEKEY")
  parser.add_option("-w", "--warn", dest="warn",
                    action="store", type="int", default=80,
                    help="Hit ratio threshold in percent thats initiates a warning",
                    metavar="WARN")
  parser.add_option("-c", "--critical", dest="critical",
                    action="store", type="int", default=60,
                    help="hit ratio threshold in percent thats initiates a critical alarm",
                    metavar="CRITICAL")
  parser.add_option("-s", "--stale", dest="stale",
                    action="store", type="int", default=2,
                    help="stale ratio threshold in percent thats initiates a critical alarm",
                    metavar="CRITICAL")
  parser.add_option("-t", "--time" , dest="time",
                    action="store", type="int", default=15,
                    help="time range in minutes to query",
                    metavar="TIME")
  return parser

######################################################################
# fetch api
######################################################################
def fetch(url, querydata):
    try:
        req = urllib2.Request(url, querydata)
        response = urllib2.urlopen(req).read()
        data = json.loads(response)
    except Exception:
        import traceback
        sys.stdout.write("ERROR: API <a href=\"{0}\" target=\"_blank\">{0}</a> could not be queried".format(url))
        sys.exit(3)
    return data

######################################################################
# check if logstash instances sends heartbeat
######################################################################
def build_query(volumekey, time):
	query_template = '''
{
    "size": 0,
    "query": {
        "filtered": {
            "filter": {
                "bool": {
                    "must": [
                        { "range": {
                            "@timestamp": {
                                "gt": "now-[TIME]m",
                                "lt": "now"
                            }
                        }},
                        { "term": { "volume_key.raw": "[VOLUMEKEY]"} }
                    ]
                }
            }
        }
    },
    "aggs": {
        "by_hit_miss" : {
            "terms" : {
                "field" : "upstream_cache_status.raw"
            },
            "aggs": {
            	"bytes_sent": {
              	    "sum": {
                        "field": "body_bytes_sent"
                    }
                }
            }
        }
    }
}
	'''
	out = query_template.replace("[VOLUMEKEY]", volumekey)
	out = out.replace("[TIME]", str(time))
	return out

######################################################################
# get hit/miss
######################################################################
def get_hit_miss(response):
    out = {
        'hit': 1,
        'hit_ratio': 100.0,
        'miss': 0,
        'miss_ratio': 0.0,
        'expired': 0,
        'expired_ratio': 0.0,
        'updating': 0,
        'updating_ratio': 0.0,
        'stale': 0,
        'stale_ratio': 0.0,
        'passed': 0,
        'passed_ratio': 0.0,
        'else': 0,
        'else_ratio': 0.0,
        'total': 0,
    }
    for i in response["aggregations"]["by_hit_miss"]["buckets"]:
        if i["key"] == "HIT": out["hit"] = i["bytes_sent"]["value"]
        elif i["key"] == "MISS": out["miss"] = i["bytes_sent"]["value"]
        elif i["key"] == "EXPIRED": out["expired"] = i["bytes_sent"]["value"]
        elif i["key"] == "UPDATING": out["updating"] = i["bytes_sent"]["value"]
        elif i["key"] == "STALE": out["stale"] = i["bytes_sent"]["value"]
        elif i["key"] == "-": out["passed"] = i["bytes_sent"]["value"]
        else:  out["else"] = out["else"] + i["bytes_sent"]["value"]

    out["total"] = out["hit"] + out["miss"] + out["expired"] + out["updating"] + out["stale"] + out["passed"] + out["else"]

    out["hit_ratio"] = out["hit"] * 100.0 / out["total"]
    out["miss_ratio"] = out["miss"] * 100.0 / out["total"]
    out["expired_ratio"] = out["expired"] * 100.0 / out["total"]
    out["updating_ratio"] = out["updating"] * 100.0 / out["total"]
    out["stale_ratio"] = out["stale"] * 100.0 / out["total"]
    out["passed_ratio"] = out["passed"] * 100.0 / out["total"]
    out["else_ratio"] = out["else"] * 100.0 / out["total"]

    return out

######################################################################
# calculate exit code
######################################################################
def calc_exit_code(stale_ratio, hit_ratio, warn, critical, stale):
    if stale_ratio > stale:
        return 2, "There are stale upstream cache stati! Are the upstream(s) healthy?"
    elif hit_ratio < critical:
        return 2, "Hit ratio of {0}% is smaller than {1}%!".format(hit_ratio, critical)
    elif hit_ratio < warn:
        return 1, "Hit ratio of {0}% is smaller than {1}%.".format(hit_ratio, warn)
    else:
        return 0, "Hit ratio of {0}% is healthy.".format(hit_ratio)

######################################################################
# execute
######################################################################
def main():
    parser = getopts()
    (options, args) = parser.parse_args()

    baseurl = "http://" + options.servername + ":" + str(options.port) + "/"

    url = baseurl + "_all/pcache/_search?pretty"
    query = build_query(options.volumekey, options.time)
    res = fetch(url, query)

    hit_miss = get_hit_miss(res)

    (exitcode, out) = calc_exit_code(hit_miss["stale_ratio"], hit_miss["hit_ratio"], options.warn, options.critical, options.stale)

    out = out + " | "
    for key,val in hit_miss.items():
        out = out + "{}={}".format(key, val) + ";;;0,"

    sys.stdout.write(out)
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
