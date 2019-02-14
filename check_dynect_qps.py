#!/usr/bin/python3

import os
import csv
import sys
import json
import datetime
import time
import requests
import math
from optparse import OptionParser
from urllib.parse import urljoin

__program__ = "check_dynect_qps"
__version__ = "0.2"

baseurl = "https://api.dynect.net/"

# It is worth rewind a little bit as Dyn reports are "near realtime",
# and requesting samples in the last 5 minutes would be incomplete,
# due to data granularity.
offset = 10

# Empirically, the report generation lasts at least 30 seconds,
# with an average of 1-2 minutes...
poll = 20


def version():
    p = "{0} v{1}\n".format(__program__, __version__)
    sys.stdout.write(p)


def getopts():
    program = os.path.basename(sys.argv[0])

    usg = "{0} [options]".format(program)
    parser = OptionParser(usage=usg)

    parser.add_option("-c", "--customer", dest="customer",
                      action="store", type="string",
                      help="customer name",
                      metavar="CUSTOMERNAME")
    parser.add_option("-u", "--user", dest="user",
                      action="store", type="string",
                      help="user name",
                      metavar="USERNAME")
    parser.add_option("-p", "--pass", dest="password",
                      action="store", type="string",
                      help="password",
                      metavar="PASSWORD")
    parser.add_option("-t", "--time", dest="time",
                      action="store", type="int", default=5,
                      help="timerange in minutes",
                      metavar="TIME")
    return parser


def login(customer, user, password):
    body = {}
    try:
        url = urljoin(baseurl, "/REST/Session/")
        data = {
            'customer_name': customer,
            'user_name': user,
            'password': password
        }
        headers = {'Content-Type': 'application/json'}
        r = requests.post(url, data=json.dumps(data), headers=headers)
        body = r.json()
        token = body['data']['token']
    except Exception as e:
        sys.stdout.write("ERROR: url: %s %s " % (url, str(body)))
        sys.exit(3)
    return token


def fetch_qps_report_ressource(token, timegap):
    total_wait = 0
    now = datetime.datetime.now()

    end = now - datetime.timedelta(minutes=offset)
    # Make timestamp of end
    end_ts = time.mktime(end.timetuple())

    start = end - datetime.timedelta(minutes=timegap)
    # Make timestamp of start
    start_ts = time.mktime(start.timetuple())

    body = {}
    try:
        url = urljoin(baseurl, "/REST/QPSReport/")
        data = {
            'start_ts': start_ts,
            'end_ts': end_ts
        }
        headers = {
            'Content-Type': 'application/json',
            'Auth-Token': token
        }
        s = requests.Session()
        # Do not allow redirects - Dyn responds with a 307 redirect to /REST/Job/<n>
        # when the job is not complete after 5s, but the job API does not support POST. Duh.
        r = s.post(url, data=json.dumps(data), headers=headers, allow_redirects=False)
        if r.is_redirect:
            redirect = urljoin(baseurl, r.headers['location'])
            loop = True
            while loop:
                r = s.get(redirect, headers=headers, allow_redirects=False)
                body = r.json()
                if body['status'] != 'incomplete':
                    loop = False
                else:
                    time.sleep(poll)
                    total_wait += poll
        else:
            body = r.json()

        if body['status'] == 'success':
            report = body['data']['csv']
        else:
            sys.stdout.write("ERROR: satus=%s : %s " % (body['status'], str(body)))
            sys.exit(3)

    except Exception as e:
        sys.stdout.write("ERROR: url: %s %s " % (url, str(body)))
        sys.exit(3)
    return (report,total_wait)


def extract_qps_stats(report):
    ts_index = 0
    qps_index = 0
    valid_rows_count = 0
    ts = 0
    qps = 0
    qps_max = 0

    # QPS granularity depends on requested time frame
    # The two first timestamps will be used to compute the granularity.
    # See also https://help.dyn.com/create-qps-report-api/
    granularity = 300 # safe default, since granularity is 5-minutes up to a span of 24 hours
    ts_1 = 0
    ts_2 = 0

    reader = csv.reader(report.split('\n'), delimiter=',')

    for ir, row in enumerate(reader):
        # get the column indexes of timestamp and qps
        if ir == 0:
            for ic, col in enumerate(row):
                if col.lower() == "timestamp":
                    ts_index = ic
                elif col.lower() == "queries":
                    qps_index = ic
        elif len(row) >= 2:
            if ir == 1:
                ts_1 = int(row[ts_index])
            if ir == 2:
                ts_2 = int(row[ts_index])
                if ts_1 > 0:
                    granularity = ts_2 - ts_1

            ts_temp = int(row[ts_index])
            qps_temp = int(row[qps_index])
            if qps_temp > 0:
                qps += qps_temp
                valid_rows_count += 1
                if qps_temp > qps_max:
                    qps_max = qps_temp

    if valid_rows_count < 1:
        sys.stdout.write("ERROR: No measure points found in report")
        sys.exit(3)

    return math.floor(qps / valid_rows_count / granularity), math.floor(qps_max / granularity)


def main():
    parser = getopts()
    (options, args) = parser.parse_args()

    token = login(options.customer, options.user, options.password)
    report,total_wait = fetch_qps_report_ressource(token, options.time)

    qps, qps_max = extract_qps_stats(report)

    sys.stdout.write("Average QPS (over the last {0}min): {1} | qps_avg={1} qps_max={2} report_time={3}".format(options.time, qps, qps_max, total_wait))
    sys.exit(0)


if __name__ == "__main__":
    main()
