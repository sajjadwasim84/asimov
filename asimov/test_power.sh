#!/bin/bash
 #Created Date Sun Feb 16 12:50:34 PST 2020
 #.....................................................
 # Purpose Of The Script To Saving Power Reading
 #.....................................................
 #Start

ipmitool -I lanplus -H 172.19.48.106 -U root -P superuser dcmi power reading >> /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_dump.txt 

grep "Average power reading over sample period:" /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_dump.txt 

# awk '{print NR") " "Watt= " $7, "KW= "$7/1000, "Cost $= "($7/1000)*744*.175}' 
#> /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_dump.txt
 #> /mnt/home/sajjadwasim/bash_scripts_2.0/power_reading_result.txt

 #End
