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
 #End

++++++++++++++++++++
/mnt/home/sajjadwasim/output2020.txt 

#!/bin/bash

report=/mnt/home/sajjadwasim/output2020.txt

get_info() {
        echo "<table><tr><th>PARTITION</th><th>TIMELIMIT</th><th>NODES</th><th>STATE</th><th>REASON</th><th>NODELIST</th><tr>" >> $report
        sinfo --noheader --format='<tr><td>%P</td><td>%l</td><td>%D</td><td>%t</td><td>%E</td><td>%N</td></tr>' >> $report
        echo "</table>" >> $report
        } 
 
 
 get_info()
cat $report


+++++++++++
echo "<table><tr><th>PARTITION</th><th>TIMELIMIT</th>&nbsp;<th>NODES</th>&nbsp;<th>STATE</th>&nbsp;<th>REASON</th>&nbsp;<th>NODELIST</th><tr>"






echo "<table><tr><th>PARTITION</th><th>TIMELIMIT</th><th>NODES</th><th>STATE</th><th>REASON</th><th>NODELIST</th><tr>" > $report
sinfo --noheader --format='<tr><td>%P</td><td>%l</td><td>%D</td><td>%t</td><td>%E</td><td>%N</td></tr>'
echo "</table>"
cat $report

++++++++++++++++++++++++++++++
#!/bin/bash
# A Shell subroutine to echo to screen and a log file

log_file_name="/some/dir/log_file.log"

echolog()
(
    echo "$@"
    echo "$@" >> $log_file_name
)


echo "no need to log this"
echolog "some important text that needs logging"


++++++++++++++++++++++++++++



log_file_name="/some/dir/log_file.log"

function write_to_log() {
  echo "$@" 
  echo >> "${log_file_name}"
}

write_to_log "some text"
do_some_command
write_to_log "more text"
do_other_command

{
  echo "some text"
  do_some_command
  echo "more text"
  do_other_command
} | tee "${log_file_name}"


+++++++++++++++

{ sha1sum foo.txt ;sha512sum foo.txt ;md5sum foo.txt ;} >checksum.txt




