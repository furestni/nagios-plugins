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

  usg = "{0} -h | -v | -w  | -c | -t | -s | -p  ".format(program)
  parser = OptionParser(usage=usg)

  parser.add_option("-s", "--server", dest="servername",
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
                    help="Threshold in percent thats initiates a warning",
                    metavar="WARN")
  parser.add_option("-c", "--critical", dest="critical",
                    action="store", type="int", default=60,
                    help="Threshold in percent thats initiates a critical alarm",
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
        'miss': 0,
        'expired': 0,
        'updating': 0,
        'stale': 0,
        'passed': 0,
        'hit_ratio': 100.0,
    }
    for i in response["aggregations"]["by_hit_miss"]["buckets"]:
        if i["key"] == "HIT": out["hit"] = i["doc_count"]
        elif i["key"] == "MISS": out["miss"] = i["doc_count"]
        elif i["key"] == "EXPIRED": out["expired"] = i["doc_count"]
        elif i["key"] == "UPDATING": out["updating"] = i["doc_count"]
        elif i["key"] == "STALE": out["stale"] = i["doc_count"]
        elif i["key"] == "-": out["passed"] = i["doc_count"]

    total = out["hit"] + out["miss"] + out["expired"] + out["updating"] + out["stale"] + out["passed"]
    out["hit_ratio"] = out["hit"] * 100.0 / total

    return out

######################################################################
# calculate exit code
######################################################################
def calc_exit_code(stale, hit_ratio, warn, critical):
    if stale > 0:
        return 2, "There are stale upstream cache stati! Are the upstream(s) healthy?"
    elif hit_ratio < critical:
        return 2, "Hit ratio ({0}%) is smaller than {1}%.".format(hit_ratio, critical)
    elif hit_ratio < warn:
        return 1, "Hit ratio ({0}%) is smaller than {1}%.".format(hit_ratio, warn)
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

    (exitcode, out) = calc_exit_code(hit_miss["stale"], hit_miss["hit_ratio"], options.warn, options.critical)

    out = out + " | "
    for key,val in hit_miss.items():
        out = out + "{} = {}".format(key, val) + ", "

    sys.stdout.write(out)
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
