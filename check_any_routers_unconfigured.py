#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# (c) 2018, René Moser <rene.moser@swisstxt.ch>


from __future__ import print_function

import sys
import argparse
import requests
import json

requests.packages.urllib3.disable_warnings()


def main():
    parser = argparse.ArgumentParser(description='')
    parser.add_argument('--protocol', default='https', help='Protocol to be used, default https')
    parser.add_argument('--port', type=int, default=443, help='Port used, default 443')
    parser.add_argument('--host', default="localhost", help='Host, default localhost')
    parser.add_argument('--filter', default="", help='Icinga2 filter')
    parser.add_argument('--username', help='Icinga2 username')
    parser.add_argument('--password', help='Icinga2 password')

    args = parser.parse_args()

    headers = {
        'Accept': "application/json",
        'X-HTTP-Method-Override': "GET",
    }
    url = "%s://%s:%s/v1/objects/services" % (args.protocol, args.host, args.port)

    filter = args.filter

    data = {
        'pretty': True,
        'attrs': ['__name', 'state'],
        'joins': ['hosts'],
    }

    if filter:
        data['filter'] = filter

    resp = requests.post(url, headers=headers, auth=(args.username, args.password), data=json.dumps(data), verify=False)

    count_results = 0
    count_errors = 0

    if resp.status_code == 200:
        for result in resp.json().get('results') or []:
            count_results = count_results + 1
            if result.get('attrs').get('state'):
                count_errors = count_errors + 1
    else:
        print("UNKNOWN: URL %s returned %s" % (url, resp.status_code))
        sys.exit(3)

    if count_errors:
        print("ERROR: %s of %s routers unhealthy" % (count_errors, count_results))
        sys.exit(2)

    if not count_results:
        print("WARNING: no results, filter?")
        sys.exit(1)

    print("OK: %s routers healthy" % count_results)
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("UNKNOWN: %s" % str(e))
        sys.exit(3)
