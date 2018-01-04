#!/usr/bin/env python

from __future__ import print_function

import sys
import argparse
import requests
import dns.resolver

requests.packages.urllib3.disable_warnings()


def get_ip_addresses(hostname):
    results = []
    answers = dns.resolver.query(hostname, 'A')
    for a in answers:
        results.append(str(a))
    return results


def main():
    parser = argparse.ArgumentParser(description='checks HTTP but uses every IP the hostname resovles to')
    parser.add_argument('--proto', default='http', help='Protocol to be used, default http')
    parser.add_argument('--hostname', required=True, help='hostname e.g. www.example.com')
    parser.add_argument('--port', default=80, help='Port to be used, default 80')
    parser.add_argument('--path', default="/", help='path e.g. /path/to, default /')
    parser.add_argument('--timeout', type=int, default=10, help='HTTP timeout in seconds')

    args = parser.parse_args()

    proto = args.proto
    hostname = args.hostname
    port = args.port
    timeout = args.timeout
    path = args.path

    ips = get_ip_addresses(hostname)

    headers = {'host': hostname}
    response = {}
    for ip in ips:
        try:
            url = "%s://%s:%s/%s" % (proto, hostname, port, path)
            r = requests.get(url, headers=headers, timeout=timeout)

            status_code = r.status_code
            if status_code != 200:
                continue

            content = r.json()

            for k, v in content.items():
                if not isinstance(v, int):
                    continue

                if k not in response:
                    response[k] = v
                else:
                    response[k] += v

        except Exception:
            continue

    response_string = "nodes_in_dns=%s" % len(ips)
    for k, v in response.items():
        response_string += " %s=%s" % (k, v)

    print("OK | " + response_string)
    sys.exit(0)


if __name__ == "__main__":
    main()
