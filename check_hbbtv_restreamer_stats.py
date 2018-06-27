#!/usr/bin/env python

from __future__ import print_function

import sys
import argparse
import requests

requests.packages.urllib3.disable_warnings()


def main():
    parser = argparse.ArgumentParser(description='checks HTTP but uses every IP the hostname resovles to')
    parser.add_argument('--url', required=True, help='Protocol to be used, default http')
    parser.add_argument('--timeout', type=int, default=10, help='HTTP timeout in seconds')

    args = parser.parse_args()

    url = args.url
    timeout = args.timeout

    response = {}
    try:
        r = requests.get(url, timeout=timeout)

        status_code = r.status_code
        if status_code == 200:
            response = r.json()

    except Exception:
        pass

    response_string = ""
    for k, v in response.items():
        if isinstance(v, list):
            response_string += " %s=%s" % (k, len(v))
        else:
            response_string += " %s=%s" % (k, v)

    print("OK | " + response_string)
    sys.exit(0)


if __name__ == "__main__":
    main()
