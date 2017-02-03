#!/usr/bin/python3

import os
import csv
import sys
import json
import datetime
import time
import requests
from optparse import OptionParser

__program__ = "check_dynect_qps"
__version__ = "0.1"

baseurl = "https://api.dynect.net/"
offset = 30

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

######################################################################
# login
######################################################################
def login(customer, user, password):
    try:
        url = baseurl + "REST/Session/"
        data = {'customer_name' : customer,
                      'user_name' : user,
                       'password' : password }
        headers = { 'Content-Type': 'application/json' }
        r = requests.post(url, data = json.dumps(data), headers = headers)
        body = r.json()
        token = body['data']['token']
    except Exception as e:
        sys.stdout.write("ERROR: url: %s %s " % (url, str(body)))
        sys.exit(3)
    return token

######################################################################
# fetch qps report link
######################################################################
def fetch_qps_report_ressource(token, timegap):
    now = datetime.datetime.now()
    end = now - datetime.timedelta(minutes=offset)
    end_ts = time.mktime(end.timetuple())
    start = end - datetime.timedelta(minutes=timegap)
    start_ts = time.mktime(start.timetuple())
    try:
        url = baseurl + "REST/QPSReport/"
        data = {
            'start_ts' : start_ts,
            'end_ts' : end_ts
        }
        headers = {
            'Content-Type': 'application/json',
            'Auth-Token': token
        }
        r = requests.post(url, data=json.dumps(data), headers=headers)
        body = r.json()
        report = body['data']['csv']
    except Exception as e:
        sys.stdout.write("ERROR: url: %s %s " % (url, str(body)))
        sys.exit(3)
    return report

######################################################################
# fetch qps report
######################################################################
def extract_latest_qps(report):
    ts_index = 0
    qps_index = 0
    row_count = 0
    ts = 0
    qps = 0

    reader = csv.reader(report.split('\n') , delimiter=',')

    for ir, row in enumerate(reader):
        # get the column indexes of timestamp and qps
        if ir == 0:
            for ic, col in enumerate(row):
                if col.lower() == "timestamp":
                    ts_index = ic
                elif col.lower() == "queries":
                    qps_index = ic
        elif len(row) > 0:
            ts_temp = int(row[ts_index])
            qps_temp = int(row[qps_index])
            if ts_temp > ts:
                ts = ts_temp
                qps = qps_temp
            row_count = ir

    if row_count < 1:
        sys.stdout.write("ERROR: No measure points found in report")
        sys.exit(3)

    return qps

######################################################################
# execute
######################################################################
def main():
    parser = getopts()
    (options, args) = parser.parse_args()

    token = login(options.customer, options.user, options.password)
    report = fetch_qps_report_ressource(token, options.time)
    qps = extract_latest_qps(report)

    sys.stdout.write("Current QPS: {0} | qps={0}".format(qps))
    sys.exit(0)

if __name__ == "__main__":
    main()
