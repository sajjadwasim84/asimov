#!/bin/bash -euE
# $Id: node-power-control.bash 1.1 2017-01-01 12:00:00Z user $ (baidu usa)
#....................................................................
# This is a handy wrapper script to handle common ipmi tasks without
# needing to memorize the passwords to the ipmi interfaces etc
#....................................................................

declare -A _GLOBALS_=()
function set_constants() {
    _GLOBALS_['debug_flag']=false
    _GLOBALS_['dry_run']=false
    ## Set defaults for command line options
    _GLOBALS_['ipmipower']=$(which ipmipower || echo "/usr/sbin/ipmipower")
    _GLOBALS_['ipmitool']=$(which ipmitool || echo "/usr/sbin/ipmitool")
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
    [ "${_GLOBALS_['dry_run']:-}" == true ] && echo "${@:-}" || eval "${@:-echo}"
}

function usage() {
    local scriptname=$(basename ${0})
    echo "node-power-control.bash: control node power states"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] <nodes> <action command>"
    echo "    -v|--verbose     be verbose"
    echo "    -h|--help        print this message"
    echo "    -n|--dry-run     don't actually do anything, just say what would be done"
    echo ""
    echo "     where <nodes> is the nodes, for example: "
    echo "         'asimov-4', 'asimov-[4-13]', 'asimov-[4,9,13]', 'svail-24', 'knl-03'"
    echo "     and <command> can be:"
    echo "         'on', 'off', 'cycle', 'reset', 'soft', 'stat', etc."
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
    # get node nanes from comma-separated nodes
    local node_string="${1:-}"
    declare -a node_list

    if [[ "${node_string}" == "" ]]; then
        echo ""
        return 0
    elif [[ "${node_string}" =~ '[' ]]; then
        local prefix_string=${node_string%%\[*}
        local remainders=${node_string#*\[}
        local current_node_string=${remainders%%\]*}
        local remaining_nodes=${remainders#*\]}
        # deal with the prefix nodes
        if [[ "${prefix_string}" =~ ',' ]]; then
            local prefix_nodes=${prefix_string%,*}
            local current_prefix=${prefix_string##*,}
            # recurse this function
            node_list+=($(get_hostlist "${prefix_nodes}"))
        else
            local current_prefix=${prefix_string}
        fi
        declare -a current_node_list
        if [[ ${current_node_string} =~ ',' ]]; then
            mapfile -td, current_node_list <<<"${current_node_string}"
        else
            local current_node_list=("${current_node_string}")
        fi
        # populate nodes from current list
        for node_item in "${current_node_list[@]}"; do
            if [[ ${node_item} =~ '-' ]]; then
                local first_n=${node_item%%-*}; local first_n=$(( ${first_n} +0))
                local last_n=${node_item#*-}; local last_n=$(( ${last_n} +0))
                for (( nodenum=${first_n}; nodenum<=${last_n}; nodenum++ )); do
                    node_list+=("${current_prefix}${nodenum}")
                done
            else
                local nodenum=$(( ${node_item} +0))
                node_list+=("${current_prefix}${node_item}")
            fi
        done
        # recurse this function
        node_list+=($(get_hostlist ${remaining_nodes#,}))
    elif [[ "${node_string}" =~ ',' ]]; then
        declare -a node_items
        mapfile -td, node_items <<<"${node_string}"
        for node_item in "${node_items[@]}"; do
            if [[ "${node_item}" != '' ]]; then
                node_list+=("${node_item}")
            fi
        done
    else
        node_list=("${node_string}")
    fi
    echo "${node_list[@]}"
}

function do_node_action() {
    # iterate through the nodes specified, doing the action specified
    nodelist=$(get_hostlist "${_GLOBALS_['nodes']}")

    for _NODE_ in ${nodelist:-none}; do
        local mgmt="mgmt"
        declare -a _FIELDS_=(${_NODE_//\-/ })

        debug echo "Running action ${_GLOBALS_['action']:-stat} on ${_NODE_}"

        _CLUSTER_="${_FIELDS_[0]:-}"
        _NUM_="${_FIELDS_[1]:-}"

        if [[ -z ${_NUM_:-} ]]; then
            echo "unknown node number specified, skipping... "
            continue
        fi

        if [[ "${_CLUSTER_:-}" == "asimov" ]] || [[ "${_CLUSTER_:-}" == "svail" ]]; then
            if [ ${_NUM_} -lt "4" ]; then
                USER="ADMIN"
                PASSWORD="ADMIN"
                WORKAROUNDS="none"
            elif [ ${_NUM_} -lt "14" ]; then
                USER="admin"
                PASSWORD="admin"
                WORKAROUNDS="none"
            elif [ ${_NUM_} -lt "24" ]; then
                USER="ADMIN"
                PASSWORD="ADMIN"
                WORKAROUNDS="none"
            elif [ ${_NUM_} -lt "144" ]; then
                USER="root"
                PASSWORD="superuser"
                WORKAROUNDS="authcap"
            elif [ ${_NUM_} -lt "224" ]; then
                USER="ADMIN"
                PASSWORD="ADMIN"
                WORKAROUNDS="none"
            elif [ ${_NUM_} -lt "244" ]; then
                USER="ADMIN"
                PASSWORD="ADMIN#00"
                WORKAROUNDS="none"
            else
                USER="root"
                PASSWORD="superuser"
                WORKAROUNDS="authcap"
            fi
        elif [[ "${_CLUSTER_:-}" == "knl" ]]; then
            USER="root"
            PASSWORD="superuser"
            WORKAROUNDS="authcap"
        elif [[ "${_CLUSTER_:-}" == "server" ]]; then
            if [ ${_NUM_} -lt "2" ]; then
		USER="root"
                PASSWORD="superuser"
            elif [ ${_NUM_} -eq "3" ]; then
                USER="root"
                PASSWORD="superuser"
                WORKAROUNDS="authcap"
            elif [ ${_NUM_} -eq "4" ]; then
                USER="ADMIN"
                PASSWORD="ADMIN"
                WORKAROUNDS="none"
            elif [ ${_NUM_} -eq "5" ]; then
                USER="root"
                PASSWORD="superuser"
                WORKAROUNDS="authcap"
             else
                echo "unknown server name, sorry"
                continue
             fi
        elif [[ "${_CLUSTER_:-}" == "io" ]]; then
            if [ ${_NUM_} -lt "9" ]; then
                USER="root"
                PASSWORD="superuser"
                WORKAROUNDS="authcap"
            else
                echo "unknown io node name, sorry"
                continue
            fi
        elif [[ "${_CLUSTER_:-}" == "dgx" ]]; then
            if [ ${_NUM_} -lt "3" ]; then
                mgmt="ipmi"
                USER="ubuntu"
                PASSWORD="ubuntu"
                WORKAROUNDS="authcap"
            else
                echo "unknown node number, sorry"
                continue
            fi
        elif [[ "${_CLUSTER_:-}" == "bd" ]]; then
            if [ ${_NUM_} -lt "2" ]; then
                USER="ADMIN"
                PASSWORD="ADMIN"
                WORKAROUNDS="none"
            else
                echo "unknown node number, sorry"
                continue
            fi
        elif [[ "${_CLUSTER_:-}" == "asimovbld" ]]; then
            if [ ${_NUM_} -lt "3" ]; then
                USER="ADMIN"
                PASSWORD="ADMIN"
                WORKAROUNDS="none"
            else
                echo "unknown node number, sorry"
                continue
            fi
        elif [[ "${_CLUSTER_:-}" == "asimovtb" ]]; then
            if [ ${_NUM_} -lt "3" ]; then
                USER="ADMIN"
                PASSWORD="ADMIN"
                WORKAROUNDS="none"
            else
                echo "unknown node number, sorry"
                continue
            fi
        else
            echo "unknown node name, sorry"
            continue
        fi

        if [[ "${_CLUSTER_:-}" == "server" ]] && [ ${_NUM_} -lt "2" ]; then
	    if [ ${_GLOBALS_['action']} = "stat" ]; then
	        _GLOBALS_['action']="status"
	    fi
	    _CMD_="${_GLOBALS_['ipmitool']} -H ${_NODE_}-${mgmt}.svail.baidu.com -I lanplus -U ${USER} -P ${PASSWORD} power ${_GLOBALS_['action']:-status}"
	else
            _CMD_="${_GLOBALS_['ipmipower']} -h ${_NODE_}-${mgmt}.svail.baidu.com -u ${USER} -p ${PASSWORD} --${_GLOBALS_['action']:-stat} -W ${WORKAROUNDS}"
	fi

        if ${_GLOBALS_['dry_run']}; then
            echo "${_CMD_}"
        else
            output=$(eval ${_CMD_}) || echo " error : exit code was : $?"
            echo "${output}"
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

# #=----------------------------------------------------------------#
# |Start our script                                                 |
# #=-|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|-=#

_GLOBALS_['nodes']="${_ARGS_[0]:-}"
_GLOBALS_['action']="${_ARGS_[1]:-}"

if [[ -z "${_GLOBALS_['nodes']:-}" ]]; then
    echo "please enter a valid node name"
    usage
elif [[ -z "${_GLOBALS_['action']:-}" ]]; then
    echo "please specify a command to take on the nodes"
    usage
else
    debug echo "running actions ${_GLOBALS_['action']} on nodes ${_GLOBALS_['nodes']}"
    do_node_action
fi


## the script exits successfully
success
#___END___#
