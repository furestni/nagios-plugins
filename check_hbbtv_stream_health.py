#!/usr/bin/env python

import sys
import argparse
import requests

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', required=True, help='Edge host name')
    parser.add_argument('--bwlimit', default=1024, help='Network bandwidth limit (MiBit/s, default 1GiBit/s)')

    args = parser.parse_args()

    host = args.host
    url = "http://{host}/health".format(host=host)
    # MiBit/s -> Byte/s
    bwlimit = args.bwlimit * 1024 * 1024 / 8

    # defaults
    message = ""
    code = 0
    viewer = 'U'
    limit = 0
    bandwidth = 'U'
    warnpercent = 0.85
    errorpercent = 0.95

    try:
        r = requests.get(url)
        data = r.json()

        status = str(data['status']).lower()
        viewer = int(data['viewer'])
        limit = int(data['limit'])
        # Nagios expects Bytes, but we have KiBit/s
        bandwidth = "{}B".format(int(data['bandwidth']) * 1024 / 8)
    except:
        message = "Node {host} could not be reached or did not return valid json".format(host=host)
        code = 2

    if code == 0:
        if status == 'ok':
            message = "Node {host} is running normally".format(host=host)
            code = 0
        elif status == "full":
            message = "Node {host} is full".format(host=host)
            code = 1
        elif status == 'offline':
            message = "Node {host} is offline".format(host=host)
            code = 2
        elif status == 'error':
            message = "Node {host} is broken".format(host=host)
            code = 2
        else:
            message = "Node {host} has unknown state '{state}'".format(host=host, state=state)
            code = 3

    prefix = ['OK', 'WARNING', 'ERROR', 'UNKNOWN'][code]
    # TODO critical viewer limit and max should not be hardcoded
    print("{prefix}: {message} | viewer={viewer};{wlimit};{elimit} bandwidth={bandwidth};{wbw};{ebw}".format(prefix=prefix, message=message, viewer=viewer, wlimit=int(limit * warnpercent),  elimit=int(limit * errorpercent), bandwidth=bandwidth, wbw=int(bwlimit * warnpercent), ebw=int(bwlimit * errorpercent)))
    sys.exit(code)

if __name__ == "__main__":
    main()

