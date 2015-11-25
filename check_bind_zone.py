#!/usr/bin/python
import sys
import time
import requests
import argparse

from datetime import datetime
from lxml import etree


parser = argparse.ArgumentParser()
parser.add_argument("--url", nargs='?', default="http://127.0.0.1:8123", help="echo the string you use here")
parser.add_argument("--zone", nargs='?', required=True , help="zone to check")
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
    out_stats = {}
    stats = {}
    for zone in xml.iter('zone'):
      name = zone.find('name').text
      if name == args.zone :
        for counter in zone.iter('counters'):
          countfail = counter.find('QryFailure').text
          countsucc = counter.find('QrySuccess').text
          countnx = counter.find('QryNXDOMAIN').text
          stats = {
          'QryFailure': countfail ,
          'QrySuccess': countsucc ,
          'QryNXDomain': countnx ,
          }
    return stats

def second_stats(url):
    start = datetime.utcnow()
    sA = get_stats(url)
    time.sleep(5)

    sB = get_stats(url)
    diff = (datetime.utcnow() - start)

    sD= {}
    for key in sA:
      sD[key] = ((int(sB[key]) - int(sA[key])) / diff.seconds )
    return sD

outstats= {}
outstats = second_stats(args.url)

perfdata = ""
for key, value in outstats.iteritems():
	perfdata = perfdata + "%s=%s " % (key, value)

##### To do.. implement warning and Critical levels

print "DNS Statistics in QPS:     %s | %s" % (perfdata, perfdata)
