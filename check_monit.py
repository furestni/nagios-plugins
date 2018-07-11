#!/usr/bin/env python2

import argparse
import base64
import os
import sys
import urllib2

# external libraries (must be installed via pip)
import xmltodict


__program__ = "check_monit"


STATUS_OK = 0
STATUS_WARNING = 1
STATUS_CRITICAL = 2
STATUS_UNKNOWN = 3


def get_argument_parser():

  program = os.path.basename(sys.argv[0])

  parser = argparse.ArgumentParser(description = "Verify Monit Health")

  parser.add_argument(  "-s", "--server",
                        required= True,
                        dest = "host",
                        action = "store",
                        help = "Monit Node Address")
  parser.add_argument(  "-p", "--port",
                        required= False,
                        dest = "port",
                        action = "store",
                        type = int,
                        default = 2812,
                        help = "Monit Node Web Admin port")
  parser.add_argument(  "-U", "--username",
                        required= True,
                        dest = "username",
                        action = "store",
                        help = "Monit Admin Password")
  parser.add_argument(  "-P", "--password",
                        required= True,
                        dest = "password",
                        action = "store",
                        help = "Monit Admin Password")

  return parser


def get_monit_health_data(baseurl, username, password):

    url = baseurl + "/_status?format=xml"
    request = urllib2.Request(url)

    request.add_header("Authorization", "Basic %s" % base64.encodestring('%s:%s' % (username, password)).replace('\n', ''))
    try:
        response = urllib2.urlopen(request).read()
        data = xmltodict.parse(response)['monit']['service']
    except Exception:
        import traceback
        sys.stdout.write("ERROR with request to {0}\n".format(url))
        sys.exit(STATUS_UNKNOWN)

    return data

def is_failing(s):
    return int(s['status']) != 0 and int(s['monitor']) == 1

def is_unmonitored(s):
    return int(s['monitor']) != 1

def main():
    errors = []
    exitcode = STATUS_OK

    # useful for local coding/debugging
    # f = open("monit_status_example.xml","r")
    # xmlFile = f.read()
    # monit_data = xmltodict.parse(xmlFile)['monit']['service']

    args = get_argument_parser().parse_args()
    baseurl = "http://{:s}:{:d}".format(args.host, args.port)
    monit_data = get_monit_health_data(baseurl, args.username, args.password)

    failing_services = filter(is_failing, monit_data)
    unmonitored_services = filter(is_unmonitored, monit_data)

    if len(unmonitored_services) > 0:
        errors.append("Unmonitored service(s): {}".format(', '.join(s['name'] for s in unmonitored_services)))
        exitcode = STATUS_WARNING

    if len(failing_services) > 0:
        errors.append("Failing service(s): {}".format(', '.join(s['name'] for s in failing_services)))
        exitcode = STATUS_CRITICAL

    result_text = ""
    if exitcode != STATUS_OK:
        result_text = ". ".join(reversed(errors))
    else:
        result_text = "Monit looks good!"

    sys.stdout.write(result_text + "\n")
    sys.exit(exitcode)


if __name__ == "__main__":
    main()
