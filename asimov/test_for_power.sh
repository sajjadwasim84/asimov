#!/bin/bash
 #Created Date Tue Feb 18 16:30:55 PST 2020
 #.....................................................
 # Purpose Of The Script
 #.....................................................
 #Start


 #for line in $(cat username_pass.txt); do
#	 echo "$line"
 #done



 while read -r line; do
ip=`echo ${line} | awk '{print $1}'`
	user=`echo ${line} | awk '{print $2}'`
	pass=`echo ${line} | awk '{print $3}'`

	date | tr -d '\n' >> /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_html.txt
	ipmitool -I lanplus -H ${ip} -U ${user} -P ${pass} dcmi power reading | grep -i "Average power reading over sample period:" | awk '{print"  Watt= " $7, "KW= "$7/1000, "Cost $= "($7/1000)*744*.175}' >> /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_html.txt

  echo -e -n  ""
done < username_pass.txt

