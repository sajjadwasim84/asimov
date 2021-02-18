#!/bin/bash -euE
# $Id: script 4 2017-01-01 12:00:00Z user $ (work_name)
#....................................................................
# This is a default template to begin writing a simple bash script
# You can add a description of your script in this box
#....................................................................

declare -A _GLOBALS_=()
function set_constants() {
    _GLOBALS_['debug_flag']=false
    _GLOBALS_['dry_run']=false
    _GLOBALS_['origin']=false
    iternodelist=(asimov-0 asimov-1 asimov-2 asimov-3 asimov-4 asimov-5 asimov-6 asimov-7 asimovtb-1 asimovtb-2 asimovbld-1 asimovbld-2)
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
    [ "${_GLOBALS_['debug_flag']:-}" == true ] && ${@:-echo} || _INVALID_=0
}

function dryrun_eval() {
    ## usage: dryrun_eval "rm -rf /tmp/deleted"
    ## WARNING: USES eval!!! Be Very Careful!
    [ "${_GLOBALS_['dry_run']:-}" == true ] && echo "${@:-}" || eval "${@:-echo}"
}

function usage() {
    # #=---------------------------------------------------------=#
    # |  Echo text about the proper usage of this script for help |
    # #=-|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|-=#
    local scriptname=$(basename ${0})
    echo "Check all active mounts to see what's mounted on the cluster"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] ..."
    echo "    -v|--verbose     be verbose"
    echo "    -h|--help        print this message"
    echo "    -n|--dry-run     don't actually do anything, just say what would be done"
    echo "    -o|--origin      show origin hosts"
    echo ""
}

function parse_opts() {
    while [ $# -gt 0 ]; do
        case ${1:-} in
            -h | --help)
                usage; success
                ;;
            -v | --verbose)
                _GLOBALS_['debug_flag']=true
                ;;
            -n | --dry-run)
                _GLOBALS_['dry_run']=true
                ;;
            -o | --origin)
                _GLOBALS_['origin']=true
                ;;
            --)
                break
                ;;
            -[[:alpha:]][[:alpha:]]*)
                split=${1}; shift
                set -- $(echo "$split" | cut -c 2- | sed 's/./-& /g') "$@"
                continue
                ;;
            --* | -?)
                echo "Not a valid option: '${1}'" >&2
                usage; success
                ;;
            *)
                break
                ;;
        esac
        shift
    done
    _ARGS_=("${@:-}")
}

function get_hostlist() {
    local INPUT=${1:-}
    local OTPUT=${2:-nodelist}
    _GLOBALS_["${OTPUT}"]=""

    declare -a _FIELDS_=(${INPUT//\[/ })
    local _NAME_="${_FIELDS_[0]:-}"
    local _NUMS_="${_FIELDS_[@]:1}"; _NUMS_="${_NUMS_%%\]}"

    if [[ "${_NUMS_:-none}" == "none" ]]; then
        _GLOBALS_["${OTPUT}"]="${_NAME_} "
    else
        declare -a _UNITS_=(${_NUMS_//,/ })
        for _unit_ in "${_UNITS_[@]}"; do
            declare -a _RANGE_=(${_unit_//\-/ })
            local _FIRST_="${_RANGE_[0]:-}"
            local _LAST_="${_RANGE_[1]:-}"

            if [[ "${_LAST_:-none}" == "none" ]]; then
                _GLOBALS_["${OTPUT}"]+="${_NAME_}${_FIRST_} "
            else
                for ((node=_FIRST_;node<=_LAST_;node++)); do
                    _GLOBALS_["${OTPUT}"]+="${_NAME_}${node} "
                done
            fi
        done
    fi
    debug echo "Action list expands to ${_GLOBALS_[${OTPUT}]}"
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
# #=-|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|-=#

queuelist=($(/usr/bin/squeue --noheader --Format=nodelist | /usr/bin/sort --uniq))
declare -A fullqlist=()
for node in ${queuelist[@]}; do
    _GLOBALS_['queuelist']=""
    get_hostlist ${node} 'queuelist'
    for node in ${_GLOBALS_['queuelist']}; do
        fullqlist["${node}"]=$((${fullqlist["${node}"]:-1} + 1))
    done
done

mapfile -d '' sorted_list < <(printf '%s\0' "${!fullqlist[@]}" | /usr/bin/sort --zero-terminated --numeric-sort --key=2 --field-separator='-')

declare -A allmounts=()

server_list=( "${iternodelist[@]}" "${sorted_list[@]}" )
for node in ${server_list[@]}; do
    ### do things
    debug echo -en "testing ${node:-}..."

    node_output=$(/usr/bin/ssh ${node:-localhost} "/bin/findmnt --types nfs4,nfs --noheadings | /usr/bin/tr --squeeze-repeats [:space:] | /usr/bin/cut --field=2 --delimiter=' ' | /usr/bin/sort --uniq" || echo "error")
    if [[ ${node_output:-} == "error" ]]; then
        debug echo -e "skip"
        continue
    else
        debug echo -e "ok"
    fi
    mapfile -t nodemounts_array < <(echo ${node_output:-})

    for entry in ${nodemounts_array:-}; do
        allmounts[${entry}]="${allmounts[${entry}]:-}${node} "
    done
    #allmounts=$(echo -e "${nodemounts[@]:-}\n${allmounts[@]:-}" | /usr/bin/sort --uniq)
done

mapfile -d '' sorted_mounts < <(printf '%s\0' "${!allmounts[@]}" | /usr/bin/sort --zero-terminated)

if ${_GLOBALS_['origin']}; then
    debug echo ""
    for mountloc in ${sorted_mounts[@]}; do
        echo "${mountloc} ${allmounts[${mountloc}]:-}"
    done
else
    debug echo ""
    for mountloc in ${sorted_mounts[@]}; do
        mountnum=$(printf "%s" "${allmounts[${mountloc}]:-}" | /usr/bin/wc --words)
        printf "%s %s\n" ${mountloc} ${mountnum}
    done
fi

## the script exits successfully
success
#___END___#
