#!/usr/bin/env python2
"""Checks the result of the last build of a Jenkins job.

    Preliminary made to use as a Icinga2-Plugin.

    Exit codes are based on Jenkins job results:
    "SUCCESS": 0
    "UNSTABLE:": 1
    "FAILURE": 2 ( can be overriden by -r argument)
    Anything else (like job not found, http errors, etc): 3

"""
# Author: Sam Friedli <samuel.friedli@swisstxt.ch>
#
import sys
import json
import requests
import argparse

### Functions
def parse_cmdln_opts():
    """Parse command line arguments."""

    parser = argparse.ArgumentParser(description = 'Icinga2 monitoring script to monitor a Jenkins job result (SUCCESS=0, FAILURE=1 (see -r), UNSTABLE=1, other=3).')

    parser.add_argument( '-J', '--jeninks-url', action='store', dest='jenkins_base_url', default='http://build.swisstxt.ch',
                         help='Base URL of Jenkins (eg. http://build.swisstxt.ch/).' )

    parser.add_argument( '-j', '--job', action='store', dest='jenkins_job_name', default='',
                         help='Name of the job to monitor.', required=True )

    parser.add_argument( '-r', '--return-code', action='store', type=int, dest='icinga_err_code', default=1,
                         help='Icinga2 plugin return code if the job result is "FAILURE" (default=1).' )

    parser.add_argument( '-u', '--user', action='store', type=str, dest='user', default='',
                         help='Username used to authenticate to Jenkins.')

    parser.add_argument( '-p', '--passwd', action='store', type=str, dest='passwd', default='',
                         help='Password used to authenticate to Jenkins.')

    return parser

### Main
req = '' # used to store the 'request'-object

# Parse command line options
cmdln_opts = parse_cmdln_opts()
opts = cmdln_opts.parse_args()

# Get job result from Jenkins
api_endpoint = opts.jenkins_base_url + "/job/" + opts.jenkins_job_name + "/lastBuild/api/json"

try:
    if opts.user:
        req = requests.get( api_endpoint, auth=( opts.user , opts.passwd ) )
    else:
        req = requests.get( api_endpoint )

    req.raise_for_status()

    json_resp = json.loads(req.content)
    job_result = json_resp['result']
except requests.exceptions.RequestException as e:
    print("Could not get job result: %s" % e)
    sys.exit(3)

# exit based on job_result
if job_result == 'SUCCESS':
    sys.exit(0)
elif job_result == 'FAILURE':
    sys.exit(opts.icinga_err_code)
else:
    sys.exit(3)
