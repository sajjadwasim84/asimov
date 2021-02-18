#!/bin/bash
 #Created Date Mon Feb 17 18:17:58 PST 2020
 #.....................................................
 # Purpose Of The Script Make Function For Power Utlization
 #.....................................................
 #Start
 
#  /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_html.txt = report
# echo -e -n  $report
 

#awk '{ SUM += $8} END { printf "%.2f",  SUM }' /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_html.txt


ipmitool -I lanplus -H 172.19.48.106 -U root -P superuser dcmi power reading >> /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_dump.txt


#cat /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_dump.txt

grep -i "Average power reading over sample period:" /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_dump.txt =  output

echo $output

 #End
