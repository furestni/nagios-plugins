#!/bin/bash
### ======================================================================= ###
#   _______          _______  _____ _____ _________   _________ 
#  / ____\ \        / /_   _|/ ____/ ____|__   __\ \ / /__   __|
# | (___  \ \  /\  / /  | | | (___| (___    | |   \ V /   | |   
#  \___ \  \ \/  \/ /   | |  \___ \\___ \   | |    > <    | |   
#  ____) |  \  /\  /   _| |_ ____) |___) |  | |   / . \   | |   
# |_____/    \/  \/   |_____|_____/_____/   |_|  /_/ \_\  |_|   
#                                                              
# Script name : dmesg.sh
# Description : Icinga/Nagios Skript to parse dmesg output
# Author      : Josef Vogt
# Created     : 02.08.2019
# Version     : 1.0
# 
### ======================================================================= ###

### ======================================================================= ###
###                          VARIABLES                                      ###
### ======================================================================= ###
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3
ERROR_SEVERITIES="emerg,alert,crit,err"
WARNING_SEVERITIES="warn"
WHITELIST="Assuming drive cache|\
SMBus Host Controller not enabled"

### ======================================================================= ###
###                         FUNCTIONS                                       ###
### ======================================================================= ###

parse_dmesg_output() {
  # Check only dmesg lines from this day
  date=$(date "+%a %b %e")
  hostname=$(hostname)

  error_output=$(dmesg -T -l "$ERROR_SEVERITIES" | grep "$date" | egrep -v "$WHITELIST" | tail -5)
  error_count=$(dmesg -T -l "$ERROR_SEVERITIES" | grep "$date" | egrep -v "$WHITELIST" | wc -l)
  warning_output=$(dmesg -T -l "$WARNING_SEVERITIES" | grep "$date" | egrep -v "$WHITELIST" | tail -5)
  warning_count=$(dmesg -T -l "$WARNING_SEVERITIES" | grep "$date" | egrep -v "$WHITELIST" | wc -l)

  if [[ "$error_output" == "" && "$warning_output" == "" ]]; then
    echo "All OK."
    exit $OK
  elif [[ "$error_output" != "" ]]; then
    echo "$error_count errors! $error_output" | xargs
    exit $CRITICAL
  elif [[ "$warning_output" != "" ]]; then
    echo "$warning_count warnings! $warning_output" | xargs
    exit $WARNING
  else
    echo "Unkown status."
    echo $UNKNWON
  fi
}

### ======================================================================= ###
###                         START SCRIPT                                    ###
### ======================================================================= ###
parse_dmesg_output
