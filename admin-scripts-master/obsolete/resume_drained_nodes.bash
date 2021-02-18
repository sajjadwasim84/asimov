#!/bin/bash -euE
# $Id: return_drain_nodes 1 2018-09-14 12:00:00Z aaron $ (baidu)

declare -A _GLOBALS_=()
function set_constants() {
    _GLOBALS_['debug_flag']=false
    _GLOBALS_['dry_run']=false
    ## Set defaults for command line options
#    _GLOBALS_['param']="default value"
    _GLOBALS_['sinfo']=$(/usr/bin/which sinfo || echo "/usr/bin/sinfo")
    _GLOBALS_['scontrol']=$(/usr/bin/which scontrol || echo "/usr/bin/scontrol")
    _GLOBALS_['nodelist']=""
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

function usage() {
    local scriptname=$(basename ${0})
    echo "This script returns nodes to idle from 'batch job complete failure'"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] ..."
    echo "    -v|--verbose     be verbose"
    echo "    -h|--help        print this message"
    echo "    -n|--dry-run     don't actually do anything, just say what would be done"
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
            -p | -p=* | --param | --param=*)
                local arg="${1#-*=*}"; local arg=${arg#--param*}; local arg=${arg#-p*};
                ## ^^ Change the --param/-p fields in the above two lines for new parameters to add
                if [[ -z ${arg:-} ]]; then local argshift=0; else local argshift=1; local arg+=" ";fi
                if [[ ! -z ${2:-} ]] && [[ "${2:0:1}" != "-" ]]; then local arg+="${@:2}";
                    if [[ "${arg:0:1}" == '"' ]] || [[ "${arg:0:1}" == "'" ]]; then
                        local arg="${arg%[\"\']*}"; local arg="${arg#*[\"\']}"; shift;
                    else local arg=${arg%%[[:space:]]-*}; shift; fi
                elif [[ ${argshift} != 1 ]]; then echo "You specified: $1, but provided no value"; usage; success;
                else argshift=0; fi
                array_to_count=(${arg}); local num_of_array=$((${#array_to_count[@]} - ${argshift}));
                _GLOBALS_['param']="${arg}"; shift "${num_of_array-1}"; continue
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

function get_drained_nodes(){
    ## get an array of the node names with their reason value for all known nodes
    readarray -t nodelist < <(${_GLOBALS_['sinfo']} --format="%n %E" --noheader)

    for nodestat in "${nodelist[@]:-}"; do
        node=${nodestat%% *}
        reason=${nodestat#* }
        if [[ ${reason:0:18} == "batch job complete" ]]; then
            _GLOBALS_['nodelist']+=" ${node}"
            debug echo "Found drained node ${node}"
        fi
    done
}

function restart_nodes(){
    if [[ ${_GLOBALS_['nodelist']} == "" ]]; then
        debug echo "No nodes to restart"
        return
    fi

    for node in ${_GLOBALS_['nodelist']}; do
        debug echo "resuming node ${node}"
        if [[ ${_GLOBALS_['dry_run']} == true ]]; then
            echo "scontrol update nodename=${node} state=resume"
        else
            ${_GLOBALS_['scontrol']} update nodename=${node} state=resume || debug echo "already resumed"
        fi
    done
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

get_drained_nodes
restart_nodes

## the script exits successfully
success
#___END___#
