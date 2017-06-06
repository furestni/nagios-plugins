#!/usr/bin/python2

import argparse
import datetime
import json
import os
import re
import sys
import urllib2


__program__ = "check_elasticsearch_indices"


STATUS_OK = 0
STATUS_WARNING = 1
STATUS_CRITICAL = 2
STATUS_UNKNOWN = 3

DAILY_SUFFIX_LENGTH = len("-YYYY.MM.DD")
TODAY = datetime.datetime.now().strftime("%Y.%m.%d")

def get_argument_parser():

  program = os.path.basename(sys.argv[0])

  parser = argparse.ArgumentParser(description = "Verify Elasticsearch Indices consistency")

  parser.add_argument(  "-s", "--server",
                        required= True,
                        dest = "servername",
                        action = "store",
                        help = "Elasticsearch address")
  parser.add_argument(  "-p", "--port",
                        required= False,
                        dest = "port",
                        action = "store",
                        type = int,
                        default = 9200,
                        help = "Elasticsearch port")
  parser.add_argument(  "-r", "--required-indices",
                        required= True,
                        dest = "required_indices",
                        action = "store",
                        help = "Comma-separated list of prefixes for the day-splitted indices that *MUST* be present")
  parser.add_argument(  "-d", "--retention-period",
                        required= False,
                        dest = "retention_period",
                        action = "store",
                        type = int,
                        default = 7,
                        help = "Retention period (in days) for the required indices")
  parser.add_argument(  "-o", "--optional-indices",
                        required= False,
                        dest = "optional_indices",
                        action = "store",
                        default = '\.kibana|\.monitoring-.+',
                        help = "Regular expression to match index names that *CAN* be present")
  parser.add_argument(  "-t", "--unknown-tolerance",
                        required= False,
                        dest = "unknown_tolerance",
                        action = "store",
                        type = int,
                        default = 0,
                        help = "Warning threshold for alerting about the presence of too many unknown indices")

  return parser


def get_elasticsearch_indices(baseurl):

    url = baseurl + "*/_stats/store"

    try:
        response = urllib2.urlopen(url).read()
        data = json.loads(response)
    except Exception:
        import traceback
        sys.stdout.write("ERROR with Elasticsearch API request <a href=\"{0}\" target=\"_blank\">{0}</a>\n".format(url))
        sys.exit(STATUS_UNKNOWN)

    perf_data = {
        "indices" : len(data["indices"]),
        "shards" : data["_shards"]["total"],
        "gigabytes" : data["_all"]["total"]["store"]["size_in_bytes"]/1073741824
    }

    indices = []
    for node in data["indices"].iteritems():
        indices.append(node[0])

    return indices, perf_data

def check_for_missing_indices(required_prefixes, indices):

    missing = []

    for i in required_prefixes:
        if (i + "-" + TODAY) not in indices:
            missing.append(i)

    return missing

def check_for_index_housekeeping(required_prefixes, indices, retention_days):

    index_counters = dict.fromkeys(required_prefixes, 0)

    for i in indices:
        if len(i) > DAILY_SUFFIX_LENGTH:
            index_name = i[:-DAILY_SUFFIX_LENGTH]
            if index_name in required_prefixes and index_name in index_counters:
                index_counters[index_name] += 1

    # The total number of index per pattern is: today + retention_days
    too_many_indices = { k: v for k, v in index_counters.iteritems() if v > (retention_days + 1) }
    return too_many_indices


def check_for_unknown_indices(required_prefixes, optional_prefixes, indices):

    r = "^(" + "|".join(required_prefixes) + ")-\d{4}\.\d{2}\.\d{2}"
    if len(optional_prefixes) > 0:
        r += "|(" + optional_prefixes + ")"
    r += "$"

    regex = re.compile(r)

    expected_indices = filter(regex.match, indices)
    return list(set(indices) - set(expected_indices))


def main():

    out = ""
    errors = []
    exitcode = STATUS_OK

    args = get_argument_parser().parse_args()

    baseurl = "http://{:s}:{:d}/".format(args.servername, args.port)
    (indices, perf_data) = get_elasticsearch_indices(baseurl)

    # ## Performance indicators: 'label'=value[UOM];[warn];[crit];[min];[max]
    perf_data_text = " |"
    for k, v in sorted(perf_data.iteritems()):
        perf_data_text += " {}={};;;0;".format(k, v)

    required_prefixes = args.required_indices.split(",")
    missing_indices = check_for_missing_indices(required_prefixes, indices)
    many_indices = check_for_index_housekeeping(required_prefixes, indices, retention_days=args.retention_period)
    unknown_indices = check_for_unknown_indices(required_prefixes, args.optional_indices, indices)

    if len(missing_indices) > 0:
        exitcode = STATUS_CRITICAL
        errors.append("Missing daily indices ({}): {}".format(TODAY, ",".join(sorted(missing_indices))))

    if len(many_indices) > 0:
        errors.append("Housekeeping needed for: " + ",".join(sorted(many_indices.keys())))
        if exitcode != STATUS_CRITICAL:
            exitcode = STATUS_WARNING

    if len(unknown_indices) > args.unknown_tolerance:
        errors.append("Too many unknown indices: " + ",".join(sorted(unknown_indices)))
        if exitcode != STATUS_CRITICAL:
            exitcode = STATUS_WARNING


    if exitcode != STATUS_OK:
        out = ". ".join(errors)
    else:
        out = "All indices look good!"

    sys.stdout.write(out + perf_data_text + "\n")
    sys.exit(exitcode)


if __name__ == "__main__":
    main()
