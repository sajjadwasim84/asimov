#!/bin/bash
 #Created Date Sun Feb 16 12:50:34 PST 2020
 #.....................................................
 # Purpose Of The Script To Saving Power Reading
 #.....................................................
 #Start

while read -r line; do 
	ip=`echo ${line} | awk '{print $1}'`
	user=`echo ${line} | awk '{print $2}'`
	pass=`echo ${line} | awk '{print $3}'`

	date | tr -d '\n' >> /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_html.txt
	ipmitool -I lanplus -H ${ip} -U ${user} -P ${pass} dcmi power reading | grep -i "Average power reading over sample period:" | awk '{print" Watt= " $7, "KW= "$7/1000, "KWH= "($7/1000)*696 }' >> /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_html.txt


done < /mnt/home/sajjadwasim/bash_scripts_2.0/username_pass.txt
