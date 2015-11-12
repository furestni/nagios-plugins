#!/usr/bin/python
import sys
import time
import requests
import argparse

from datetime import datetime
from lxml import etree


parser = argparse.ArgumentParser()
parser.add_argument("--url", nargs='?', default="http://127.0.0.1:8123", help="echo the string you use here")
args = parser.parse_args()


def get_counter_value(xml, path):
    counters = xml.xpath(path)
    out = 0
    for c in counters:
        out += int(c)
    return out


def get_stats(url):
    response = requests.get(url)
    xml=etree.fromstring(response.content)

    stats = {
        'server.requests': '/isc/bind/statistics/server/nsstat[name="Requestv4" or name="Requestv6"]/counter/text()',
        'server.query.successes': '/isc/bind/statistics/server/nsstat[name="QrySuccess"]/counter/text()',
        'server.query.failures': '/isc/bind/statistics/server/nsstat[name="QryNxrrset" or name="QrySERVFAIL" or name="QryFORMERR" or name="QryNXDOMAIN" or name="QryDropped" or name="QryFailure"]/counter/text()',
        'resolver.query.sent': '/isc/bind/statistics/views/view/resstat[name="Queryv4" or name="Queryv6"]/counter/text()',
        'resolver.query.received': '/isc/bind/statistics/views/view/resstat[name="Responsev4" or name="Responsev6"]/counter/text()',
        'resolver.query.errors': '/isc/bind/statistics/views/view/resstat[name="NXDOMAIN" or name="SERVFAIL" or name="FORMERR" or name = "OtherError"]/counter/text()',
        }

    out_stats = {}
    for key, path in stats.iteritems():
        out_stats[key] = get_counter_value(xml, path)
    return out_stats


def second_stats(url):
    start = datetime.utcnow()
    sA = get_stats(url)
    time.sleep(30)

    sB = get_stats(url)
    diff = (datetime.utcnow() - start)

    millis = diff.seconds * 1000 +  diff.microseconds / 1000.0
    norm = 1000.0/millis

    sD= {}
    for key in sA:
        sD[key] = round((sB[key] - sA[key]) * norm, 2)
    return sD

outstats= {}
outstats = second_stats(args.url)

perfdata = ""
for key, value in outstats.iteritems():
	perfdata = perfdata + "%s=%s " % (key, value)

print "DNS Statistics %s | %s" % (perfdata, perfdata)

#if outstats['serverrequests'] > 1:
#  sys.exit(1)
