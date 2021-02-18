#!/bin/bash

#ps axuf | egrep -v ^root | tr -s " " | cut -f1,11- -d' ' | column -c2
processes=$(ps axu | egrep -v '(^root|^syslog|^statd|^ntp|^dnsmasq|^daemon|^ganglia|^munge|^postfix|^systemd|^nobody)' | tail -n+2 | awk '{ printf"%-9s", $1; $1=$2=$3=$4=$5=$6=$7=$8=$9=$10=""; printf"%-70s\n", $0}')
all_clear=$(echo -e "${processes}" | egrep -v 'message+' || echo 'none')

if [[ ${all_clear:-} == 'none' ]]; then
    echo -e " : no unknown processes : "
else
    echo -e "....processes...."
    echo -e "${all_clear}" | sort
fi


sync
mounts=$(df --portability --type=nfs --type=nfs4 | tail -n+2 | awk '{ printf"%-35s", $1; printf"%-35s\n", $6}' | egrep -v "(asimov/admin/config|asimov/tools|asimov/admin/scripts|io-.-ib:/work)" || echo 'none')

if [[ ${mounts:-} == 'none' ]]; then
    echo -e " : no unknown mounts : "
else
    echo -e "....mounts...."
    echo -e "${mounts}" | sort
fi
