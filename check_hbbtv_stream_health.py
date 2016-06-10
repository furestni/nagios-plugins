#!/usr/bin/env python

import sys
import argparse
import requests

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', required=True, help='edge host name')

    args = parser.parse_args()

    host = args.host
    url = "http://{host}/health".format(host=host)

    # defaults
    message = ""
    code = 0
    viewer = 'U'
    limit = 0
    bandwidth = 'U'

    try:
        r = requests.get(url)
        data = r.json()

        status = str(data['status']).lower()
        viewer = int(data['viewer'])
        limit = int(data['limit'])
        # Nagios expects KiByte/s, but we have KiBit/s
        bandwidth = "{}KB".format(int(data['bandwidth']) / 8)
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
    print("{prefix}: {message} | viewer={viewer};{limit};1000 bandwidth={bandwidth}".format(prefix=prefix, message=message, viewer=viewer, limit=limit, bandwidth=bandwidth))
    sys.exit(code)

if __name__ == "__main__":
    main()

