#!/usr/bin/python
# Check Router internet Availability
import argparse
import sys
import os

try:
    from cs import CloudStack, CloudStackException, read_config
except ImportError:
    print 'python library required: cs'
    print 'pip install <library>'
    sys.exit(1)

parser = argparse.ArgumentParser()

parser.add_argument('--project')
parser.add_argument('--zone')

args = parser.parse_args()

try:
    cs = CloudStack(**read_config())

    project_id = ''
    if args.project:
        projects = cs.listProjects(listall=True)
        if projects:
            for p in projects['project']:
                if p['name'] == args.project:
                    project_id = p['id']
                    break

    if not project_id:
        print "project %s not found" % args.project
        sys.exit(1)

    zone_id = ''
    if args.zone:
        zones = cs.listZones()
        if zones:
            for z in zones['zone']:
                if z['name'] == args.zone:
                    zone_id = z['id']
                    break

    if not zone_id:
        print "zone %s not found" % args.zone
        sys.exit(1)
     
    vms = {}
    vms = cs.listRouters(projectid=project_id)
    if vms:
        for vm in vms['router']:
            pod_ip = None
            for n in vm['nic']:
                if n['traffictype'] == 'Control':
                    if vm['zoneid'] == zone_id:
                        pod_ip = n['ipaddress']
                        arglist = ' -C "ping 8.8.8.8 -c 1" > /dev/null '
                        cmd = 'ssh root@' + str(pod_ip) + arglist 

                        retvalue = os.system(cmd)
                        if not retvalue:
                            print "OK - no packetloss on router: %s" % ( vm['name'] )
                            exit(0)
                        else:
                            print "Critical - packetloss on router: %s" % ( vm['name'] )
                            exit(2)

except CloudStackException, e:
    print "CloudStackException: %s" % str(e)
    sys.exit(1)

