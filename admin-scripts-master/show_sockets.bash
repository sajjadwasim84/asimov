#!/bin/bash

function get_tcp_info() {
    ### get tcp info from ss and parse it
    ###
    local -a output_array=()
    mapfile -t output_array < <(/bin/ss --ipv4 --resolve --extended --process --memory --info --no-header | /usr/bin/paste - - | /usr/bin/tr --delete '\t' | /usr/bin/tr --squeeze-repeats '[:space:]' | /usr/bin/cut --fields=6- --delimiter=' ' | /usr/bin/sort --key=2 --general-numeric-sort --field-separator='-' )

    #header
    echo -e "nodename  user  dlvrrate  pacerate  send  lastsend  busy  retrans  sockdrop"

    declare -A uid_array
    for entry in "${output_array[@]}"; do
        local target_host=${entry%%\ *}
        local target_data=${entry##${target_host}\ }
        local ext_data=${target_data%%<->*}
        local data_rem=${target_data##*<->\ }
        local skmem=${data_rem%%\ *}
        local ss_info=${data_rem##${skmem}\ }
        local nodename=${target_host%%\:*}

        unset ext_array
        declare -A ext_array
        for elem in ${ext_data}; do
            local key=${elem%%\:*}
            local value=${elem##*\:}
            ext_array[${key}]=${value}
        done

        local uid_info=${ext_array['uid']}
        if [[ -z ${uid_info} ]]; then
            local ps_info="${ext_array['users']}"
            local ps_name="${ps_info%\"*}"
            local pd_info="${ps_info##${ps_name}\"\,pid=}"
            local user_info="${ps_name##*\"}:${pd_info%%\,*}"
            continue
        else
            if [[ -z ${uid_array[${uid_info}]} ]]; then
                ## memoize user lookup
                local uid_output=$(/usr/bin/getent passwd ${uid_info})
                uid_array[${uid_info}]=${uid_output%%\:*}
            fi
            local user_info=${uid_array[${uid_info}]:-nobody}
        fi

        local pvals=${skmem#skmem\:\(}
        local pvals=${pvals%\)}
        local mem_pval=${pvals//,/ }

        unset mem_array
        declare -A mem_array
        for val in ${mem_pval}; do
            local metric="${val%%[0-9]*}"
            local value="${val##*[a-z]}"
            case $metric in
                'rb') local key="rcv_buf" ;;
                'tb') local key="snd_buf" ;;
                'bl') local key="back_log" ;;
                'f') local key="fwd_alloc" ;;
                'd') local key="sock_drop" ;;
                'r') local key="rmem_alloc" ;;
                't') local key="wmem_alloc" ;;
                'w') local key="wmem_queued" ;;
                'o') local key="opt_mem" ;;
                *) local key=${metric} ;;
            esac
            mem_array[${key}]="${value}"
        done

        declare -A ss_array
        for item in ${ss_info}; do
            if [[ ${item} == 'send' ]] || \
               [[ ${item} == 'pacing_rate' ]] || \
               [[ ${item} == 'delivery_rate' ]]; then
                last=${item}
                continue
            elif [[ ${item} == 'ts' ]] || \
                 [[ ${item} == 'sack' ]] || \
                 [[ ${item} == 'cubic' ]] || \
                 [[ ${item} == 'ecn' ]] || \
                 [[ ${item} == 'ecnseen' ]] || \
                 [[ ${item} == 'fastopen' ]] || \
                 [[ ${item} == 'conf_alg' ]] || \
                 [[ ${item} == 'app_limited' ]]; then
                ss_array[${item}]=true
                continue
            fi
            if [[ ! -z ${last} ]]; then
                ss_array[${last}]=${item}
                unset last
                continue
            fi
            local key="${item%%\:*}"
            local value="${item##*\:}"
            ss_array[${key}]="${value}"
        done

        local ss_list="${ss_array['delivery_rate']} ${ss_array['pacing_rate']} ${ss_array['send']} ${ss_array['lastsnd']} ${ss_array['busy']} ${ss_array['retrans']} ${mem_array['sock_drop']}"
        echo -e "${nodename} ${user_info} ${ss_list} "
    done
}
get_tcp_info | /usr/bin/column -t
