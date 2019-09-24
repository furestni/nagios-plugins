#!/usr/bin/python
# Sam Friedli, 05.2019 @ SwissTXT

"""Checks if a incoming Stream to a specific application on Wowza-Server has status "connected"

    Return values are meant to be used by Icinga/nagios.
    0/OK        = Stream is connected
    1/WARNING   = (Used only for testing)
    2/CRITICAL  = Stream is offline
    3/UNKNOWN   = Could not get status, eg. all connection related issues like API not reachable and all other script errors etc.

    Uses the Wowza-REST API, so it must obviously be enabled... --> https://www.wowza.com/docs/wowza-streaming-engine-rest-api

"""

import argparse
import sys
import json
import requests

from requests.auth import HTTPDigestAuth

### defaults
wowza_api_request_header = { 'Accept': 'application/json' }

### Functions

def parse_cmdln_args():
    """Parse command line arguments."""

    parser = argparse.ArgumentParser( description = 'Icinga2 plugin to check incoming streams to Wowza-Application.' )

    parser.add_argument( '-S', '--server', action='store', dest='wowza_server', default='',
                         help='Wowza server to check.', required=True)
    parser.add_argument( '-P', '--port', action='store', dest='wowza_server_port', default="8087",
                         help='Wowza API port (default: 8087)', required=False )
    parser.add_argument( '-a,', '--application', action='store', dest='wowza_app', default='',
                         help='Wowza Application.', required=True)
    parser.add_argument( '-s', '--streams', action='store', dest='streams_to_check', nargs='+', default='',
                         help='List of stream names to check.', required=True)
    parser.add_argument( '-u', '--user', action='store', dest='wowza_user', default='',
                         help='User used to connect to the Wowza-API.', required=False)
    parser.add_argument( '-p', '--password', action='store', dest='wowza_passwd', default='',
                         help='Password for the Wowza-API user.', required=False)
    parser.add_argument( '-d', '--digest', action='store', dest='wowza_use_digest_auth', type=bool, default=True,
                         help='Use digest authentication instead of basic.', required=False)
    parser.add_argument( '-e', '--err-code', action='store', type=int, dest='err_code', default=2,
                         help='Error code when at least one stream is not found or not connected.', required=False)


    return parser

def check_streams(streams, args):
    """Check if the streams given via cmd arguments are in the list of incoming streams in the given application on the wowza server"""

    return_code = 0 # if all streams are found and connected, this will remain untouched

    # create a list of all incoming streams and their connection status
    incoming_streams = {}
    for i in streams:
        incoming_streams[i['name']] = i['isConnected']

    # check if given streams are in list of streams found for the given application on the given wowza server
    for s in args.streams_to_check:
        if s in incoming_streams:
            if incoming_streams[s] == True:
                # print("Stream %s is there and connected.") ## not needed/wanted for Icinga..uncomment for debug purposes
                continue
            else:
                # Stream is in list but is not connected
                print("%s not connected." % s)
                return_code = args.err_code
        else:
            # Stream is not even found
            print("Stream %s not found!" % s)
            return_code = args.err_code

    return(return_code)

def main():
    cmdln_args = parse_cmdln_args()
    args = cmdln_args.parse_args()

    # Get incoming stream list
    wowza_api_endpoint = "http://"  + args.wowza_server + ":" + args.wowza_server_port + "/v2/servers/_defautlServer_/vhosts/_defaultVHost_/applications/" + args.wowza_app + "/instances/_definst_"

    try:
        if args.wowza_user:
            if args.wowza_use_digest_auth == True:
                req = requests.get( wowza_api_endpoint, auth=HTTPDigestAuth(args.wowza_user, args.wowza_passwd), headers=wowza_api_request_header )
            else:
                req = requests.get( wowza_api_endpoint, auth=(args.wowza_user, args.wowza_passwd), headers=wowza_api_request_header )
        else:
            req = requests.get( wowza_api_endpoint, headers=wowza_api_request_header )

        req.raise_for_status() # raise exception on unsuccessfull http requests (like 404, 403, 500 etc)
        json_resp = json.loads(req.content)
        #print(req.status_code)
        streams = json_resp['incomingStreams']
        sys.exit(check_streams(streams, args))

    except requests.exceptions.RequestException as e:
        print("Could not get stream list: %s" % e)
        sys.exit(3)

if __name__ == "__main__":
    main()
