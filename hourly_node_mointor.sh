#!/bin/bash
report=/mnt/home/sajjadwasim/code/kw_request_log.txt

get_info() {
        echo $1 >> $report
        sinfo -Nel | grep "$1" | wc -l >> $report
}

echo -e -n  "" > $report
get_info "idle"
get_info "mix\|resv\|alloc"
get_info "drain"
cat $report
