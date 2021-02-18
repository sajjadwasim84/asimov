#!/bin/bash -euE
# $Id: ipa_create_user.sh 2 2017-01-01 12:00:00Z user $ (baidu)
#....................................................................
#  This is a script to create ipa users via cli
#....................................................................

function set_constants() {
    _DEBUG="off"
    ENTRY=()
    _keytab_="/root/password.keytab"
    _SCRATCH_SERVER_="server-3"
    _HOME_SERVER_="server-4"
    _DATA_SERVER_="server-2"
    _NEW_PASSWORD_="AInewpassword"
    _DRY_RUN_=false
}

function define_colors() {
    _bCOLORS=0; _NUM_COLORS=$(tput colors 2>/dev/null) || _bCOLORS="${?}"
    if [[ ${_bCOLORS} == "0" ]] && [[ ${_NUM_COLORS} -gt 2 ]]; then
        #foreground='39' or '38', background='49' or '48'
        c_clear='\000\033[0;39;49m' ; c_bold='\00\00\00\033[1;39;49m'
        c_underline='\033[4;39;49m' ; c_inverse='\00\00\033[7;39;49m'
        c_red='\00\00\033[0;31;49m' ; c_brightred='\000\033[1;31;49m'
        c_green='\000\033[0;32;49m' ; c_brightgreen='\0\033[1;32;49m'
        c_yellow='\00\033[0;33;49m' ; c_brightyellow='\0033[1;33;49m'
        c_blue='\00\0\033[0;34;49m' ; c_brightblue='\00\033[1;34;49m'
        c_magenta='\0\033[0;35;49m' ; c_brightmagenta='\033[1;35;49m'
        c_cyan='\00\0\033[0;36;49m' ; c_brightcyan='\00\033[1;36;49m'
        c_black='\000\033[0;40;49m' ; c_grey='\00\00\00\033[1;40;49m'
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
    local exit_status="${1:-${?}}" ; if [[ "${exit_status}" == *[![:digit:]]* ]]; then exit_status=1; fi
    local exit_message="${2:-unknown error}"
    echo -en "${c_red}Fatal error ${exit_status} in function ${error_function} on line ${c_brightred}${error_linenum}${c_clear}: ${exit_message} \n"
    dirs -c
    exit $exit_status
}
function success() {
    onexit 0
}
function onexit() {
    local exit_status=${1:-$?}
    if [ ${exit_status} == 0 ]; then
        dirs -c
        exit $exit_status
    else
    debug echo -en "Script: ${0} stopped\n"
    dirs -c
    exit $exit_status
    fi
}

function debug() {
    [ "$_DEBUG" == "on" ] && ${@:-echo} || _INVALID_=0
}

function usage() {
    local scriptname=$(basename ${0})
    echo "A script to enter new users in IPA over cli using existing passwd entries"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] ([-f] <filename> | [-e] <passwd entry> | <passwd entry>)"
    echo ""
    echo "    -v|--verbose                be verbose"
    echo "    -h|--help                   print this message"
    echo "    -f|--file <filename>        a filename to parse for multiple passwd entries"
    echo "    -e|--entry <passswd entry>  a single line from a passwd file to parse"
    echo "    -u|--firstname <first name> users first name [optional]"
    echo "    -l|--lastname  <last name>  users last name [optional]"
    echo "    -m|--email <users email>    users email [optional]"
    echo "    -n|--dry-run                dont do anything, just say what would be done"
    echo ""
}

function parse_opts() {
    while [ $# -gt 0 ]; do
        case ${1:-} in
            -v | --verbose)
                _DEBUG="on"
                ;;
            -h | --help)
                usage; success
                ;;
            -n | --dry-run)
                _DRY_RUN_=true
                ;;
            -u | -u=* | --firstname | --firstname=*)
                local arg="${1#-*=*}"; local arg=${arg#--firstname*}; local arg=${arg#-u*};
                if [[ -z ${arg:-} ]]; then local argshift=0; else local argshift=1; local arg+=" ";fi
                if [[ ! -z ${2:-} ]] && [[ "${2:0:1}" != "-" ]]; then local arg+="${@:2}";
                    if [[ "${arg:0:1}" == '"' ]] || [[ "${arg:0:1}" == "'" ]]; then
                        local arg="${arg%[\"\']*}"; local arg="${arg#*[\"\']}"; shift;
                    else local arg=${arg%%[[:space:]]-*}; shift; fi
                elif [[ ${argshift} != 1 ]]; then echo "You specified: $1, but provided no value"; usage; success;
                else argshift=0; fi
                array_to_count=(${arg}); local num_of_array=$((${#array_to_count[@]} - ${argshift}));
                FIRSTNAME="${arg}";     shift "${num_of_array-1}"; continue
                ;;
            -l | -l=* | --lastname | --lastname=*)
                local arg="${1#-*=*}"; local arg=${arg#--lastname*}; local arg=${arg#-l*};
                if [[ -z ${arg:-} ]]; then local argshift=0; else local argshift=1; local arg+=" ";fi
                if [[ ! -z ${2:-} ]] && [[ "${2:0:1}" != "-" ]]; then local arg+="${@:2}";
                    if [[ "${arg:0:1}" == '"' ]] || [[ "${arg:0:1}" == "'" ]]; then
                        local arg="${arg%[\"\']*}"; local arg="${arg#*[\"\']}"; shift;
                    else local arg=${arg%%[[:space:]]-*}; shift; fi
                elif [[ ${argshift} != 1 ]]; then echo "You specified: $1, but provided no value"; usage; success;
                else argshift=0; fi
                array_to_count=(${arg}); local num_of_array=$((${#array_to_count[@]} - ${argshift}));
                LASTNAME="${arg}";     shift "${num_of_array-1}"; continue
                ;;
            -m | -m=* | --email | --email=*)
                local arg="${1#-*=*}"; local arg=${arg#--email*}; local arg=${arg#-m*};
                if [[ -z ${arg:-} ]]; then local argshift=0; else local argshift=1; local arg+=" ";fi
                if [[ ! -z ${2:-} ]] && [[ "${2:0:1}" != "-" ]]; then local arg+="${@:2}";
                    if [[ "${arg:0:1}" == '"' ]] || [[ "${arg:0:1}" == "'" ]]; then
                        local arg="${arg%[\"\']*}"; local arg="${arg#*[\"\']}"; shift;
                    else local arg=${arg%%[[:space:]]-*}; shift; fi
                elif [[ ${argshift} != 1 ]]; then echo "You specified: $1, but provided no value"; usage; success;
                else argshift=0; fi
                array_to_count=(${arg}); local num_of_array=$((${#array_to_count[@]} - ${argshift}));
                EMAIL="${arg}";     shift "${num_of_array-1}"; continue
                ;;
            -f | -f=* | --file | --file=*)
                local arg="${1#-*=*}"; local arg=${arg#--file*}; local arg=${arg#-f*};
                if [[ -z ${arg:-} ]]; then local argshift=0; else local argshift=1; local arg+=" ";fi
                if [[ ! -z ${2:-} ]] && [[ "${2:0:1}" != "-" ]]; then local arg+="${@:2}";
                    if [[ "${arg:0:1}" == '"' ]] || [[ "${arg:0:1}" == "'" ]]; then
                        local arg="${arg%[\"\']*}"; local arg="${arg#*[\"\']}"; shift;
                    else local arg=${arg%%[[:space:]]-*}; shift; fi
                elif [[ ${argshift} != 1 ]]; then echo "You specified: $1, but provided no value"; usage; success;
                else argshift=0; fi
                array_to_count=(${arg}); local num_of_array=$((${#array_to_count[@]} - ${argshift}));
                FILENAME="${arg}";     shift "${num_of_array-1}"; continue
                ;;
            -e | -e=* | --entry | --entry=*)
                local arg="${1#-*=*}"; local arg=${arg#--entry*}; local arg=${arg#-e*};
                if [[ -z ${arg:-} ]]; then local argshift=0; else local argshift=1; local arg+=" ";fi
                if [[ ! -z ${2:-} ]] && [[ "${2:0:1}" != "-" ]]; then local arg+="${@:2}";
                    if [[ "${arg:0:1}" == '"' ]] || [[ "${arg:0:1}" == "'" ]]; then
                        local arg="${arg%[\"\']*}"; local arg="${arg#*[\"\']}"; shift;
                    else local arg=${arg%%[[:space:]]-*}; shift; fi
                elif [[ ${argshift} != 1 ]]; then echo "You specified: $1, but provided no value"; usage; success;
                else argshift=0; fi
                array_to_count=(${arg}); local num_of_array=$((${#array_to_count[@]} - ${argshift}));
                ENTRY[0]="${arg}";     shift "${num_of_array-1}"; continue
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
    ARGS=("${@:-}")
}

# #=------------------------------------------------------------=#
function create_automounts()
{
    local _user_=${@:-}
    local _home_mount_=''
    local _mount_opts_="-fstype=nfs4,vers=4.1,rw,sec=sys,soft,intr"

    if ${_DRY_RUN_}; then
        echo "I would have run this:"
        echo "ipa automountkey-add default --key ${_user_} --info ${_mount_opts_} ${_HOME_SERVER_}-ib:/home/${_user_} auto.home"
        echo "ipa automountkey-add default --key ${_user_} --info ${_mount_opts_} ${_SCRATCH_SERVER_}-ib:/scratch/${_user_} auto.scratch"
        echo "ipa automountkey-add default --key ${_user_} --info ${_mount_opts_},noatime ${_DATA_SERVER_}-ib:/storage-8/data/${_user_} auto.data"
    else
        debug echo "creating automounts for user ${_user_}"
        ipa automountkey-add default --key "${_user_}" --info "${_mount_opts_} ${_HOME_SERVER_}-ib:/home/${_user_}" auto.home
        ipa automountkey-add default --key "${_user_}" --info "${_mount_opts_} ${_SCRATCH_SERVER_}-ib:/scratch/${_user_}" auto.scratch
        ipa automountkey-add default --key "${_user_}" --info "${_mount_opts_},noatime ${_DATA_SERVER_}-ib:/storage-8/data/${_user_}" auto.data
    fi
}

function create_user() {
    local USER_ENTRY="${@:-}"
    _username_=''
    _uid_=''
    _gidnumber_=''
    _gecos_=''
    _homedir_=''
    _shell_=''
    _first_=''
    _last_=''
    _email_=''

    _username_=$(echo ${USER_ENTRY:-} | cut -s -f1 -d:)
    if [[ -z ${_username_} ]]; then error 1 "Invalid entry for username"; fi
    _sep_=$(echo ${USER_ENTRY:-} | cut -s -f2 -d:)
    _uid_=$(echo ${USER_ENTRY:-} | cut -s -f3 -d:)
    if [[ -z ${_uid_} ]]; then error 1 "Invalid entry for user id"; fi
    _gidnumber_=$(echo ${USER_ENTRY:-} | cut -s -f4 -d:)
    if [[ -z ${_gidnumber_} ]]; then error 1 "Invalid entry for group id"; fi
    _gecos_=$(echo ${USER_ENTRY:-} | cut -s -f5 -d:)
    _homedir_=$(echo ${USER_ENTRY:-} | cut -s -f6 -d:)
    if [[ -z ${_homedir_} ]]; then error 1 "Invalid entry for home directory"; fi
    _shell_=$(echo ${USER_ENTRY:-} | cut -s -f7 -d:)
    if [[ -z ${_shell_} ]]; then error 1 "Invalid entry for user shell"; fi

    if [[ -z ${FIRSTNAME:-} ]] && [[ -z ${LASTNAME:-} ]] && [[ -z ${EMAIL:-} ]]; then
        echo "Please verify gecos data for user ${_username_}:"
    fi
    if [[ -z ${FIRSTNAME:-} ]]; then
        echo -n "First Name > "; read _first_
    else
        _first_=${FIRSTNAME:-}
    fi
    if [[ -z ${LASTNAME:-} ]]; then
        echo -n "Last Name > " ; read _last_
    else
        _last_=${LASTNAME:-}
    fi
    if [[ -z ${EMAIL:-} ]]; then
        echo -n "Email Address > "; read _email_
    else
        _email_=${EMAIL:-}
    fi

    ## get rid of trailing whitespace!!!
    _first_=${_first_%"${_first_##*[![:space:]]}"}
    _last_=${_last_%"${_last_##*[![:space:]]}"}
    _email_=${_email_%"${_email_##*[![:space:]]}"}

    if ${_DRY_RUN_}; then
        echo "I would have run this: \n/usr/bin/ipa user-add ${_username_} --password --uid=\"${_uid_}\" --gidnumber=\"${_gidnumber_}\" --gecos=\"${_gecos_}\" --first=\"${_first_}\" --last=\"${_last_}\" --email=\"${_email_}\" --homedir=\"${_homedir_}\" --shell=\"${_shell_}\"" || error 1 "broken"
    else
        debug echo "running ipa user-add script for user ${_username_}"
        echo ${_NEW_PASSWORD_:-AInewpassword} | /usr/bin/ipa user-add "${_username_}" --password --uid="${_uid_}" --noprivate --gidnumber="${_gidnumber_}" --first="${_first_}" --last="${_last_}" --email="${_email_}" --gecos="${_gecos_}" --homedir="${_homedir_}" --shell="${_shell_}"
        /usr/bin/ipa user-show "${_username_}"
    fi

    create_automounts ${_username_}
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
# #=----------------------------------------------------------------#
if [[ ! -z ${ENTRY[@]:-} ]]; then
    debug echo "Only parsing cli entry: ${ENTRY[@]}"
elif [[ ! -z ${ARGS[@]:-} ]]; then
    ENTRY[0]="${ARGS[@]}"
    debug echo "Only parsing cli entry: ${ENTRY[@]}"
elif [[ -f ${FILENAME:-} ]]; then
    FILE_FOUND=$(/bin/readlink -f ${FILENAME:-/dev/null} || echo /dev/null)
    debug echo "You specified a filename to parse: ${FILE_FOUND:-}"

    debug echo "Parsing entry: ${ENTRY:-}"
    readarray ENTRY < "${FILE_FOUND:-}"
else
    usage; error 1 "Please specify an option for parsing user data as detailed above."
fi

debug echo "running 'kinit admin -k -t ${_keytab_}'"
/usr/bin/kinit admin -k -t ${_keytab_}

for entry in "${ENTRY[@]}"; do
    create_user "${entry}"
done

## the script exits successfully
success
#___END___#