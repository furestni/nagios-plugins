#!/usr/bin/env python2
"""Checks the result of the last build of a Jenkins job.

   Todo: Implement authentication
"""
# Author: Sam Friedli <samuel.friedli@swisstxt.ch>
#
import json
import requests
import argparse

### Functions
def parse_cmdln_opts():
    """Parse command line arguments."""

    parser = argparse.ArgumentParser(description = 'Icinga2 monitoring script to monitor a Jenkins-Job result')

    parser.add_argument( '-J', '--jeninks-url', action='store', dest='jenkins_base_url', default='http://build.swisstxt.ch',
                         help='Base URL of Jenkins (eg. http://build.swisstxt.ch/)' )

    parser.add_argument( '-j', '--job', action='store', dest='jenkins_job_name', default='',
                         help='Name of the job to monitor', required=True )

    parser.add_argument( '-r', '--return-code', action='store', type=int, dest='icinga_err_code', default=1,
                         help='Icinga2 plugin return code if the job failed.' )

    return parser

### Main
# Parse command line options
cmdln_opts = parse_cmdln_opts()
opts = cmdln_opts.parse_args()

# Get job result from Jenkins
api_endpoint = opts.jenkins_base_url + "/job/" + opts.jenkins_job_name + "/lastBuild/api/json"
try:
    r = requests.get( api_endpoint )
    r.raise_for_status()

    json_resp = json.loads(r.content)
    job_result = json_resp['result']
except requests.exceptions.RequestException as e:
    print("Could not get job result: %s" % e)
    exit(3)

# exit based on job_result
if job_result == 'SUCCESS':
    exit(0)
elif job_result == 'FAILURE':
    exit(opts.icinga_err_code)
else:
    exit(3)
