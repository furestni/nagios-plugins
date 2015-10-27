#!/usr/bin/env python

import sys
import atexit
import argparse
import getpass
import pyVmomi

from pyVmomi import vim
from pyVmomi import vmodl

from pyVim import connect
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vmodl

import requests
requests.packages.urllib3.disable_warnings()

def get_args():
    parser = argparse.ArgumentParser()

    parser.add_argument('-s', '--host',
                        required=True,
                        action='store',
                        help='Remote host to connect to')

    parser.add_argument('-o', '--port',
                        required=False,
                        action='store',
                        help="port to use, default 443", default=443)

    parser.add_argument('-u', '--user',
                        required=True,
                        action='store',
                        help='User name to use when connecting to host')

    parser.add_argument('-p', '--password',
                        required=False,
                        action='store',
                        help='Password to use when connecting to host')

    args = parser.parse_args()
    if args.password is None:
        args.password = getpass.getpass(
            prompt='Enter password for host %s and user %s: ' %
                   (args.host, args.user))

    args = parser.parse_args()

    return args

def check():
    args = get_args()
    # form a connection...
    try:
        si = SmartConnect(host=args.host, user=args.user, pwd=args.password, port=args.port)
    except Exception as exc:
        if isinstance(exc, vim.fault.HostConnectFault) and '[SSL: CERTIFICATE_VERIFY_FAILED]' in exc.msg:
            try:
                import ssl
                default_context = ssl._create_default_https_context
                ssl._create_default_https_context = ssl._create_unverified_context
                si = SmartConnect(host=args.host, user=args.user, pwd=args.password, port=args.port)
                ssl._create_default_https_context = default_context
            except Exception as exc1:
                raise Exception(exc1)
        else:
            raise Exception(exc)

    atexit.register(connect.Disconnect, si)

    # Retreive the list of Virtual Machines from the inventory objects
    # under the rootFolder
    content = si.content
    objView = content.viewManager.CreateContainerView(content.rootFolder,
                                                    [vim.VirtualMachine],
                                                    True)
    vmList = objView.view
    objView.Destroy()

    vms = []
    for vm in vmList:
        if vm.runtime.powerState == "poweredOn" and vm.guestHeartbeatStatus.lower() != "green":
            vms.append(vm.summary.config.name)

    if not vms :
        return 0, "OK: all green"

    elif vms:
        return 1, "WARNING: %s VMs bad vmware tools heartbeat status: %s" % (len(vms), ','.join(vms))

def main():

    (exitcode, out) = check()

    sys.stdout.write("{0}\n".format(out))
    sys.exit(exitcode)

if __name__ == "__main__":
    main()
