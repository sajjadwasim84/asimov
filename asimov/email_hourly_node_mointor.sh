#!/bin/bash
 #Created Date Tue Feb 4 02:05:33 PST 2020
 #...............................................................
 # Purpose Of The Script is to monintor hourly node status
 #..............................................................
 #Start

#!/bin/bash
report=/mnt/home/sajjadwasim/bash_scripts_2.0/log_file_hourly_node_mointor.txt

get_info() {
        echo $1 >> $report
        sinfo -Nel | grep "$1" | wc -l >> $report
 	}

echo -e -n  "" > $report
get_info "idle"
get_info "mix\|resv\|alloc"
get_info "drain"
cat $report


##recipients=" wasim@baidu.com muhammadwasim@baidu.com"
##subject="cluster Hourly Health"
##cat $report | mail -s $subject @ recipients


mail -s "Test Subject" wasim@baidu.com < /dev/null 
 #End
