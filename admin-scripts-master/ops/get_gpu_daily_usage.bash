#!/bin/bash -euE
# $Id: script 4 2020-09-09 12:00:00Z aaron $ (baidu usa)
#....................................................................
# This is a script to tabulate gpu hours etc on slurm nodes
#....................................................................

declare -A PARTGPUS
declare -A PARTCPUS
declare -A PARTNODES
declare -a PARTLIST

declare -A _GLOBALS_=()
declare -a _ARGS_
function set_constants() {
    _GLOBALS_['debug_flag']=false
    _GLOBALS_['dry_run']=false
    ## Set defaults for command line options
    _GLOBALS_['day']='01'
    _GLOBALS_['month']='01'
    _GLOBALS_['tres']='gres/gpu'
}

function define_colors() {
    local _bCOLORS=0; local _NUM_COLORS=$(tput colors 2>/dev/null) || local _bCOLORS="${?}"
    if [[ ${_bCOLORS} == "0" ]] && [[ ${_NUM_COLORS} -gt 2 ]]; then
        #foreground='39' or '38', background='49' or '48'
            c_clear='\e[0;39;49m' ;          c_bold='\e[1;39;49m'
        c_underline='\e[4;39;49m' ;       c_inverse='\e[7;39;49m'
            c_black='\e[0;30;49m' ;          c_grey='\e[1;30;49m'
              c_red='\e[0;31;49m' ;     c_brightred='\e[1;31;49m'
            c_green='\e[0;32;49m' ;   c_brightgreen='\e[1;32;49m'
           c_yellow='\e[0;33;49m' ;  c_brightyellow='\e[1;33;49m'
             c_blue='\e[0;34;49m' ;    c_brightblue='\e[1;34;49m'
          c_magenta='\e[0;35;49m' ; c_brightmagenta='\e[1;35;49m'
             c_cyan='\e[0;36;49m' ;    c_brightcyan='\e[1;36;49m'
            c_white='\e[0;37;49m' ;   c_brightwhite='\e[1;37;49m'
    else
        c_clear=''; c_bold=''; c_underline=''; c_inverse=''
        c_red=''; c_brightred=''; c_green=''; c_brightgreen=''
        c_yellow=''; c_brightyellow=''; c_blue=''; c_brightblue=''
        c_magenta=''; c_brightmagenta=''; c_cyan=''; c_brightcyan=''
        c_black=''; c_grey=''
    fi
}

#....................................................................
# define the error/exit captures
#....................................................................
function error() {
    ## usage:  error ${?:-ERR_CODE} "message"
    ## this function is used to capture errors in the script manually
    local error_function="${FUNCNAME[1]}"
    local error_linenum="${BASH_LINENO[0]}"
    local exit_status="${1:-${?}}" ; if [[ "${exit_status:-}" == *[![:digit:]]* ]]; then exit_status=1; fi
    local exit_message="${2:-unknown error}"
    echo -en "${c_red}Fatal error ${exit_status:-unknown} in function ${error_function:-unknown} on line ${c_brightred}${error_linenum:-unknown}${c_clear}: ${exit_message:-unknown} "
    dirs -c
    exit ${exit_status}
}
function success() {
    onexit 0
}
function onexit() {
    local exit_status=${1:-$?}
    if [ ${exit_status} == 0 ]; then
        dirs -c
        exit ${exit_status}
    else
    echo -en "Script: ${0} stopped\n"
    dirs -c
    exit ${exit_status}
    fi
}

function debug() {
    ## usage: debug echo "This is a debug message for example"
    [ "${_GLOBALS_['debug_flag']:-}" == true ] && ${@:-echo} >&2 || _INVALID_=0
}

function dryrun_eval() {
    ## usage: dryrun_eval "rm -rf /tmp/deleted"
    ## WARNING: USES eval!!! Be Very Careful!
    [ "${_GLOBALS_['dry_run']:-}" == true ] && echo "${@:-}" || eval "${@:-echo}"
}

function usage() {
    local scriptname=$(basename ${0})
    echo "A description of this script"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] [-d] <##> [-m] <##> [-t] <cpu|gres/gpu> [-g] <csv> ..."
    echo "    -v|--verbose     be verbose"
    echo "    -h|--help        print this message"
    echo "    -m|--month       use month for caclulation"
    echo "    -d|--day         use day"
    echo "    -g|--group       use this grouping override"
    echo "    -t|--tres        use tres 'gres/gpu' or 'cpu'"
    echo ""
}

function parse_opts() {
    unset _nextval_
    for _argv_ in "${@:-}"; do
        if [[ ! -z ${_nextval_:-} ]]; then
            _GLOBALS_[${_nextval_}]=${_argv_}
            unset _nextval_
            continue
        fi
        shopt -s extglob
        case "${_argv_}" in
            -h | --help)
                usage; success
                ;;
            -v | --verbose)
                _GLOBALS_['debug_flag']=true
                ;;
            -n | --dry-run)
                _GLOBALS_['dry_run']=true
                ;;
            -d | -d=* | --day | --day=*)
                _argv_="${_argv_##@(--|-)@(d|day)?(=| )}"
                if [[ -z "${_argv_:-}" ]]; then _nextval_="day"
                else _GLOBALS_['day']=${_argv_}; fi
                continue
            ;;
            -m | -m=* | --month | --month=*)
                _argv_="${_argv_##@(--|-)@(m|month)?(=| )}"
                if [[ -z "${_argv_:-}" ]]; then _nextval_="month"
                else _GLOBALS_['month']=${_argv_}; fi
                continue
            ;;
            -* | -*=*)
                echo "Not a valid option: '${_argv_}'" >&2
                usage; success
            ;;
            *)
                _ARGS_+=(${_argv_})
                continue
            ;;
        esac
        shopt -u extglob
    done
}

function fill_node_arrays() {
    # sinfo get node data to fill arrays
    debug echo "getting node information, please wait"
    local sinfo_output=$(/usr/bin/sinfo --noheader --format='%P|%D|%c|%G')

    for part_data in ${sinfo_output}; do
        mapfile -t -d '|' part_array <<< ${part_data}
        local part_name=${part_array[0]%%\*}
        local part_num=${part_array[1]}
        local part_cpu=${part_array[2]}
        local part_gpu=${part_array[3]##*\:}; local part_gpu=${part_gpu%%$'\n'}

        PARTLIST+=(${part_name})
        PARTGPUS[${part_name}]=${part_gpu/(null)/0}
        PARTCPUS[${part_name}]=${part_cpu}
        PARTNODES[${part_name}]=${part_num}
    done

    debug echo "partition list is ${PARTLIST[@]}"
}

function sum() {
    string=${@}
    total=0
    for num in ${string:-0}; do
        total=$(( total + num ))
    done
    echo "${total:-0}"
}

function ceiling_divide() {
    # lets get the ceiling for usage
    local nom=${1:-0}
    local den=${2:-1}
    ceiling_result=$(((${nom}+${den}-1)/${den}))
    echo "${ceiling_result}"
}

function get_all_gpu_usage() {
    ## lets get some hourly data about usage
    local tres=${_GLOBALS_['tres']}
    local day=$(printf "%02d" "${_GLOBALS_['day']}")
    local month=$(printf "%02d" "${_GLOBALS_['month']}")

    #STARTTIME=${_GLOBALS_['starttime']}
    #ENDTIME=${_GLOBALS_['endtime']}

    # start function
    debug echo "getting all job data, please wait..."

    declare -A PARTDATA

    for hour in {00..23}; do
        # set the start and end times
        local start="2020-${month}-${day}T${hour}:00:00"
        local end="2020-${month}-${day}T${hour}:59:59"

        # get sacct info
        jobinfo=$(/usr/bin/sacct --noheader --format="User,JobName,Partition,AllocGRES,CPUTimeRaw" --parsable2 \
        --starttime ${start} --endtime ${end} |\
        /bin/egrep --invert-match '^\||\|$' || echo 'nobody|none|none|gpu:0|0')
        debug echo -en "-"

        sorted_by_part=$(echo -e "${jobinfo}" | /usr/bin/sort -k3 -t'|')
        # parse for data

        for part in "${PARTLIST[@]}"; do
            this_partition=$(echo -e "${sorted_by_part}" | /bin/egrep "(\|${part}\||\|${part},)" || echo 'nobody|none|none|gpu:0|0')
            gpu_jobs=$(echo -e "${this_partition}" | /bin/fgrep '|gpu:' || echo 'nobody|none|none|gpu:0|0' )
            total_gpus=$(echo -e "${gpu_jobs}" | /usr/bin/cut -f4 -d$'|' | /usr/bin/awk -F ':' '{sum += $2} END {print sum}')
            PARTDATA[${part}]+="${total_gpus}|"
            debug echo -en "."
        done
    done
    debug echo "parsing job data, please wait..."

    echo "Hourly report for ${month}-${day}:" >&2
    echo "part,     total avail, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23"

    for part in "${PARTLIST[@]}"; do
        norm_val=${PARTGPUS[${part}]:-0}
        nodenum=${PARTNODES[${part}]:-0}
        tot_norm=$(( nodenum * norm_val ))

        mapfile -t -d'|' fields_out<<<${PARTDATA[${part}]}
        ## print part and total avail
        printf "%-16s, %3d," "${part}" "${tot_norm}"
        len=${#fields_out[@]}
        for hour_unit in "${fields_out[@]::${len}-1}"; do
            if [[ "${hour_unit:-0}" -gt ${tot_norm} ]]; then
                hour_unit=${tot_norm}
            fi
            printf "%3d," "${hour_unit:-0}"
            debug echo -en "."
        done
        printf "\n"
    done
    debug echo -e "Done"
}


#....................................................................
# we've called bash with -euE, exit on error and error on unset variables
# so define some error prodedures to take when erroring out:
#....................................................................
trap onexit HUP INT TERM QUIT EXIT
trap error ERR ILL
set -o nounset -o errexit
#....................................................................
#  Defining variables we're using and handle options
#....................................................................
set_constants
define_colors
parse_opts ${@:-}

# #=----------------------------------------------------------------#
# |Start our script                                                 |
# |put the guts of your script in here. Functions are defined above.|
# #=-|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|-=#
# '  V  V  V  V  V  V  V  V  V  V  V  V  V  V  V  V  V  V  V  V  V  '
fill_node_arrays
get_all_gpu_usage

## the script exits successfully
success
#___END___#

