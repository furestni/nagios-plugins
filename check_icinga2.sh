#!/bin/bash

# definitions
SERVICE='icinga2.service'
STATE='active (running)'

# check the state
systemctl status $SERVICE | grep \"${STATE}\" > /dev/null 2>&1

# output message
if [ $? -ne 0 ]; then
	echo "Icinga2 seems to have problems!"
	exit 2;
else
	echo "Icinga2 is working properly! :)"
	exit 0;
fi
