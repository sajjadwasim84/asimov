#!/bin/bash -euE
# $Id: create-new-asimov-user 2 2017-01-01 12:00:00Z athomas $ (baidu)
#....................................................................
# This script is for creating users on the asimov and svail cluster
#....................................................................

declare -A _GLOBALS_=()
function set_constants() {
    _GLOBALS_['debug']="off"
    _GLOBALS_['dry_run']=false
    _GLOBALS_['test_run']=false
    _GLOBALS_['max_uid']=6400
    _GLOBALS_['scratch_server']="server-3"
    _GLOBALS_['home_server']="server-4"
    _GLOBALS_['data_server']="data-0"
    _GLOBALS_['archive_server']="archive"
    _GLOBALS_['asimov_slurm_server']="asimov-0-log"
    _GLOBALS_['svail_slurm_server']="svail-0"
    _GLOBALS_['domain_url']="svail.baidu.com"
    _GLOBALS_['ipa_keytab_file']="/root/password.keytab"
    _GLOBALS_['user_group']="svail"
    _GLOBALS_['user_gid']=1001
    _GLOBALS_['user_shell']="/bin/bash"
    _GLOBALS_['password']="AInewpassword"
    ## these must match each other for user_exists:
    _GLOBALS_['nis_server']="server-0"
    _GLOBALS_['ipa_server']="admin-0"
    _GLOBALS_['user_exists_server-0']=false
    _GLOBALS_['user_exists_admin-0']=false


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
    [ "${_GLOBALS_['debug']}" == "on" ] && ${@:-echo} || _INVALID_=0
}

function usage() {
    local scriptname=$(basename ${0})
    echo "This script is used for creating new users in svail"
    echo ""
    echo "Usage: ${scriptname} [-v] [-h] [-n] [-u] <username> [-f] <first> [-l] <last> [-e] <email>"
    echo "    -v|--verbose     be verbose"
    echo "    -h|--help        print this message"
    echo "    -n|--dry-run     don't do anything, say what would be done"
    echo "    -t|--test-run    test the run commands instead of doing them, for sanity"
    echo "    -u|--username    the new user login name"
    echo "    -f|--first       first name of the user"
    echo "    -l|--last        last name of the user"
    echo "    -e|--email       user's email address"
    echo "    -i|--uid         override auto-uid lookup with this uid"
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
            -t | --test-run)
                _GLOBALS_['test_run']=true
                ;;
            -u | -u=* | --username | --username=*)
                _argv_="${_argv_##@(--|-)@(u|username)?(=| )}"
                if [[ -z "${_argv_:-}" ]]; then _nextval_="username"
                else _GLOBALS_['username']=${_argv_}; fi
                continue
            ;;
            -i | -i=* | --uid | --uid=*)
                _argv_="${_argv_##@(--|-)@(i|uid)?(=| )}"
                if [[ -z "${_argv_:-}" ]]; then _nextval_="next_uid"
                else _GLOBALS_['next_uid']=${_argv_}; fi
                continue
            ;;
            -f | -f=* | --first | --first=*)
                _argv_="${_argv_##@(--|-)@(f|first)?(=| )}"
                if [[ -z "${_argv_:-}" ]]; then _nextval_="firstname"
                else _GLOBALS_['firstname']=${_argv_}; fi
                continue
            ;;
            -l | -l=* | --last | --last=*)
                _argv_="${_argv_##@(--|-)@(l|last)?(=| )}"
                if [[ -z "${_argv_:-}" ]]; then _nextval_="lastname"
                else _GLOBALS_['lastname']=${_argv_}; fi
                continue
            ;;
            -e | -e=* | --email | --email=*)
                _argv_="${_argv_##@(--|-)@(e|email)?(=| )}"
                if [[ -z "${_argv_:-}" ]]; then _nextval_="emailaddr"
                else _GLOBALS_['emailaddr']=${_argv_}; fi
                continue
            ;;
            -g | -g=* | --group | --group=*)
                _argv_="${_argv_##@(--|-)@(g|group)?(=| )}"
                if [[ -z "${_argv_:-}" ]]; then _nextval_="usergroup"
                else _GLOBALS_['usergroup']=${_argv_}; fi
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


function resolve_hostname() {
    local _host_=${1:-localhost}
    local _hostip_=$(/usr/bin/getent ahostsv4 ${_host_} | /bin/grep STREAM | /usr/bin/head -n 1 | /usr/bin/awk '{ print $1 }')
    echo "${_hostip_}"
}

function get_next_uid() {
    output_varname=${1:-none}
    MIN_UID=1001
    LDAP_HOST="${_GLOBALS_['ipa_server']}.${_GLOBALS_['domain_url']}"
    BASE_DN="cn=users,cn=accounts,dc=svail,dc=baidu,dc=com"

    debug echo "debug: getting next available UID for user"
    local ldap_output=$(/usr/bin/ssh ${LDAP_HOST} "/usr/bin/ldapsearch -x -h ${LDAP_HOST} -b ${BASE_DN} -LLL -S uidNumber 'uid=*' uid uidNumber 2>/dev/null || echo \"-1\" " || echo "-1")
    if [[ ${ldap_output:-} == "-1" ]]; then error 1 "error with ldapsearch lookup"; fi
    local user_list=$(echo -e "${ldap_output}" | sed -En '/uid: /{N;s/[^:]*: (.*)\n[^:]*: (.*)/\2\ \1/p;}' | sort -k1 -h | cut -f1 -d' ')
    local last_uid=${MIN_UID}
    local max_uid=${_GLOBALS_['max_uid']:-0}

    for item in ${user_list}; do
        if [[ ${item} -lt ${max_uid} ]] && [[ ${item} -gt ${last_uid} ]]; then
            local last_uid=${item}
        fi
    done

    local next_uid=$(( last_uid + 1))
    _GLOBALS_["${output_varname}"]="${next_uid}"
}

function create_ipa_automounts()
{
    ## set up our variables
    local _username_="${_GLOBALS_['username']:-nobody}"
    local _locations_=('default' 'compute_node_v4' 'interactive_node_v4')
    declare -A _opts_home_array_=( \
        ['default']="-fstype=nfs4,vers=4.2,rw,sec=sys,soft,noatime" \
        ['compute_node_v4']="-fstype=nfs4,vers=4.2,rw,sec=sys,soft,noatime" \
        ['interactive_node_v4']="-fstype=nfs4,vers=4.2,rw,sec=sys,soft,noatime" \
        )
    declare -A _opts_scrt_array_=( \
        ['default']="-fstype=nfs4,vers=4.2,rw,sec=sys,soft,noatime" \
        ['compute_node_v4']="-fstype=nfs4,vers=4.2,rw,sec=sys,soft,noatime" \
        ['interactive_node_v4']="-fstype=nfs4,vers=4.2,rw,sec=sys,soft,noatime" \
        )
    declare -A _opts_data_array_=( \
        ['default']="-fstype=nfs4,vers=4.2,rw,sec=sys,soft,noatime" \
        ['compute_node_v4']="-fstype=nfs4,vers=4.2,rw,sec=sys,soft,noatime" \
        ['interactive_node_v4']="-fstype=nfs4,vers=4.2,rw,sec=sys,soft,noatime" \
        )
    declare -A _opts_arch_array_=( \
        ['default']="-fstype=nfs4,vers=4.2,ro,noatime,soft,noatime" \
        ['compute_node_v4']="-fstype=nfs4,vers=4.2,ro,noatime,soft,noatime" \
        ['interactive_node_v4']="-fstype=nfs4,vers=4.2,rw,noatime,soft,noatime" \
        )
    local _ipahost_="${_GLOBALS_['ipa_server']}.${_GLOBALS_['domain_url']}"
    local _auth_host_="${_GLOBALS_['ipa_server']}"
    local _keytab_=${_GLOBALS_['ipa_keytab_file']}
    local _auto_cmd_="automountkey-add"

    declare -A _mount_servers_=( \
        [home]="${_GLOBALS_['home_server']}-ib" \
        [scratch]="${_GLOBALS_['scratch_server']}-ib" \
        [data]="${_GLOBALS_['data_server']}-ib" \
        [archive]="${_GLOBALS_['archive_server']}-ib" \
        )
    declare -A _mount_paths_=( \
        [home]="home"\
        [scratch]="scratch" \
        [data]="data" \
        [archive]="archive" \
        )

    debug echo " "
    for _location_ in ${_locations_[@]}; do
        declare -A _mount_array_=( \
            [home]="${_opts_home_array_[${_location_}]}" \
            [scratch]="${_opts_scrt_array_[${_location_}]}" \
            [data]="${_opts_data_array_[${_location_}]}" \
            [archive]="${_opts_arch_array_[${_location_}]}" \
            )

        for mountloc in "${!_mount_array_[@]}"; do
            mount_opt="${_mount_array_[${mountloc}]}"
            mount_server="${_mount_servers_[${mountloc}]}"
            mount_path="${_mount_paths_[${mountloc}]}"

            debug echo -en "debug: testing for autofs entry existence.."
            amount_exists=$(/usr/bin/ssh ${_ipahost_} "/usr/bin/kinit admin -k -t ${_keytab_} 2>/dev/null 1>/dev/null && /usr/bin/ipa automountkey-find ${_location_} auto.${mountloc} --key=${_username_} 2>/dev/null 1>/dev/null && echo \$? || echo \$?" || error $? "error with ssh to ipa host")
            if [[ "${amount_exists}" == "0" ]]; then
                debug echo ". will modify existing keys in ${_location_} for auto.${mountloc}"
                local _auto_cmd_="automountkey-mod"
            elif [[ ${amount_exists} == "1" ]]; then
                debug echo ". will add new keys in ${_location_} for auto.${mountloc}"
                local _auto_cmd_="automountkey-add"
            else
                error ${amount_exists} "Error with searching for automount key ${_username_} in ${_location_} for auto.${mountloc}"
            fi

            if ${_GLOBALS_['test_run']}; then
                    echo "Testrun: skipping create ipa automounts in ${_location_} for auto.${mountloc}"
                continue
            fi
            if ${_GLOBALS_['dry_run']}; then
                echo "Dryrun - not executed: /usr/bin/ssh ${_ipahost_} \"/usr/bin/kinit admin -k -t ${_keytab_}; ipa ${_auto_cmd_} ${_location_} --key ${_username_} --info \'${mount_opt} ${mount_server}:/${mount_path}/${_username_}\' auto.${mountloc}"
                continue
            fi
            ## only get here by failing above if statements...
            debug echo "debug: Creating/updating automount entries in ${_location_} for ${mountloc}..."
            /usr/bin/ssh ${_ipahost_} "/usr/bin/kinit admin -k -t ${_keytab_}; /usr/bin/ipa ${_auto_cmd_} ${_location_} --key ${_username_} --info \"${mount_opt} ${mount_server}:/${mount_path}/${_username_}\" \"auto.${mountloc}\""
        done
    debug echo " "
    done
}

function create_ipa_user() {
    ## server info
    local _ipahost_="${_GLOBALS_['ipa_server']}.${_GLOBALS_['domain_url']}"
    local _auth_host_="${_GLOBALS_['ipa_server']}"
    local _keytab_="${_GLOBALS_['ipa_keytab_file']}"
    ## user info
    local _username_="${_GLOBALS_['username']:-nobody}"
    local _uid_="${_GLOBALS_['next_uid']:-0}"
    local _gidnumber_=${_GLOBALS_['user_gid']}
    local _homedir_="/mnt/home/${_username_}"
    local _shell_="${_GLOBALS_['user_shell']:-/bin/bash}"
    local _password_=${_GLOBALS_['password']}

    local _first_="${_GLOBALS_['firstname']:-nobody}"
    local _last_="${_GLOBALS_['lastname']:-nobody}"
    local _email_="${_GLOBALS_['emailaddr']:-nobody}"
    local _gecos_="${_first_} ${_last_}, ${_email_},"

    if ${_GLOBALS_["user_exists_${_auth_host_}"]}; then
        debug echo "debug: skipping user ${_username_}: already in IPA"
    elif ${_GLOBALS_['test_run']}; then
        echo "todo: test create ipa user..."
    elif ${_GLOBALS_['dry_run']}; then
        echo "Dryrun: /usr/bin/ssh ${_ipahost_} \" /usr/bin/kinit admin -k -t ${_keytab_}; echo ${_password_} | /usr/bin/ipa user-add ${_username_} --password --uid=${_uid_} --gidnumber=${_gidnumber_} --gecos=\\\"${_gecos_}\\\" --first=\\\"${_first_}\\\" --last=\\\"${_last_}\\\" --email=\\\"${_email_}\\\" --homedir=${_homedir_} --shell=${_shell_} --noprivate"
    else
        debug echo "debug: creating user in ipa"
        output=$(/usr/bin/ssh ${_ipahost_} "/usr/bin/kinit admin -k -t ${_keytab_}; echo ${_password_} | /usr/bin/ipa user-add ${_username_} --password --uid=${_uid_} --noprivate --gidnumber=${_gidnumber_} --first=\"${_first_}\" --last=\"${_last_}\" --email=\"${_email_}\" --gecos=\"${_gecos_}\" --homedir=${_homedir_} --shell=${_shell_} || (err=\${?:-1}; echo error with ipa \${err:-UNKNOWN}; return \${err:-1})" || (err=${?:-1}; echo "error with ssh ${err:-UNKNOWN}"; return ${err:-1}) ) || error ${?} "error with ipa register: ${?}"
        debug echo -e "${output}"
        #/usr/bin/ssh ${_ipahost_} "/usr/bin/kinit admin -k -t ${_keytab_}; /usr/bin/ipa user-show \"${_username_}\""
    fi
}

function create_nfs_mounts() {
    local _home_server_="${_GLOBALS_['home_server']}.${_GLOBALS_['domain_url']}"
    local _scratch_server_="${_GLOBALS_['scratch_server']}.${_GLOBALS_['domain_url']}"
    local _data_server_="${_GLOBALS_['data_server']}.${_GLOBALS_['domain_url']}"
    local _archive_server_="${_GLOBALS_['archive_server']}.${_GLOBALS_['domain_url']}"
    local _group_="${_GLOBALS_['user_group']}"
    local _username_="${_GLOBALS_['username']}"

    local hqs=251658240
    local hqh=262144000
    local home_mount="/exports/home"
    local sqs=524288000
    local sqh=529530880
    local scratch_mount="/exports/scratch"
    local dqs=104857600
    local dqh=110100480
    local data_mount="/exports/data"
    local aqs=5347737600
    local aqh=5368709120
    local archive_mount="/exports/archive"

    create_home_command="mkdir ${home_mount}/${_username_}; "
    create_home_command+="chown ${_username_}:${_group_} ${home_mount}/${_username_}; "
    create_home_command+="/usr/sbin/setquota --format=vfsv1 --user ${_username_} ${hqs} ${hqh} 0 0 ${home_mount}; "
    create_home_command+="/usr/bin/rsync --archive --chown=${_username_}:${_group_} /etc/skel/ ${home_mount}/${_username_}; "

    create_scratch_command="mkdir ${scratch_mount}/${_username_}; "
    create_scratch_command+="chown ${_username_}:${_group_} ${scratch_mount}/${_username_}; "
    create_scratch_command+="/usr/sbin/setquota --format=vfsv1 --user ${_username_} ${sqs} ${sqh} 0 0 ${scratch_mount}; "

    create_data_command="mkdir ${data_mount}/${_username_}; "
    create_data_command+="chown ${_username_}:${_group_} ${data_mount}/${_username_}; "
    create_data_command+="/usr/sbin/xfs_quota -x -c 'limit bsoft=${dqs}k bhard=${dqh}k ${_username_}' ${data_mount}; "

    create_archive_command="mkdir ${archive_mount}/${_username_}; "
    create_archive_command+="chown ${_username_}:${_group_} ${archive_mount}/${_username_}; "
    create_archive_command+="/usr/sbin/xfs_quota -x -c 'limit bsoft=${aqs}k bhard=${aqh}k ${_username_}' ${archive_mount}; "

    if ${_GLOBALS_['dry_run']}; then
        echo "I would have run:"
        echo "/usr/bin/ssh ${_home_server_:-localhost} \"${create_home_command}\""
        echo "/usr/bin/ssh ${_scratch_server_:-localhost} \"${create_scratch_command}\""
        echo "/usr/bin/ssh ${_data_server_:-localhost} \"${create_data_command}\""
        echo "/usr/bin/ssh ${_archive_server_:-localhost} \"${create_archive_command}\""
    elif ${_GLOBALS_['test_run']}; then
        echo "todo: test create nfs mounts"
    else
        debug echo "debug: creating directories on nfs servers and applying quotas"

        debug echo "debug: creating home ${home_mount:-}/${_username_:-} on ${_home_server_:-}"
        /usr/bin/ssh ${_home_server_:-localhost} "${create_home_command}"
        debug echo "debug: creating scratch ${scratch_mount:-}/${_username_:-} on ${_scratch_server_:-}"
        /usr/bin/ssh ${_scratch_server_:-localhost} "${create_scratch_command}"
        debug echo "debug: creating data ${data_mount:-}/${_username_:-} on ${_data_server_:-}"
        /usr/bin/ssh ${_data_server_:-localhost} "${create_data_command}"
        debug echo "debug: creating archive ${archive_mount:-}/${_username_:-} on ${_archive_server_:-}"
        /usr/bin/ssh ${_archive_server_:-localhost} "${create_archive_command}"
    fi
}

function create_slurm_user() {
    cluster=${1:-}
    _username_="${_GLOBALS_['username']}"
    _asimov_slurm_server_="${_GLOBALS_['asimov_slurm_server']}.${_GLOBALS_['domain_url']}"

    if [[ ${cluster} == "asimov" ]]; then
        if ${_GLOBALS_['dry_run']}; then
            echo "I would have run:"
            echo "ssh ${_asimov_slurm_server_} \"/usr/bin/sacctmgr add user ${_username_} Account=svail Cluster=asimov-cluster\""
        elif ${_GLOBALS_['test_run']}; then
            echo "todo: test create slurm user asimov"
        else
            debug echo "debug: Adding user to asimov slurm"
            /usr/bin/ssh ${_asimov_slurm_server_} "/usr/bin/sacctmgr -i add user ${_username_} Account=svail Cluster=asimov-cluster"
        fi
    else
        error 1 "unknown cluster name"
    fi
}

function preflight() {
    local scratch_s=${_GLOBALS_['scratch_server']}
    local home_s=${_GLOBALS_['home_server']}
    local data_s=${_GLOBALS_['data_server']}
    local archive_s=${_GLOBALS_['archive_server']}
    local aslurm_s=${_GLOBALS_['asimov_slurm_server']}
    local ipa_s=${_GLOBALS_['ipa_server']}

    declare -A slurm_prefix_dict=( ['asimov-0-log']="/usr/bin/" )
    local -a ssh_hosts=(${scratch_s} ${home_s} ${data_s} ${archive_s} ${aslurm_s} ${ipa_s})
    local -a slurm_hosts=(${aslurm_s})
    local -a auth_hosts=(${ipa_s})

    local _username_="${_GLOBALS_['username']:-nobody}"
    local _uid_="${_GLOBALS_['next_uid']:-0}"

    function do_auth_host() {
        ## check if we can auth to the respective host - warning; abstraction violation
        auth_host=${1:-}
        local _keytab_="${_GLOBALS_['ipa_keytab_file']}"

        if [[ ${auth_host} == ${ipa_s} ]]; then
            debug echo "Preflight: Checked host ${auth_host}"
            ipa_service=$(/usr/bin/ssh "${auth_host}.${_GLOBALS_['domain_url']}" "/usr/bin/kinit admin -k -t ${_keytab_} 2>/dev/null 1>/dev/null && echo \$? || echo \$?" 2>/dev/null || echo $?)
            if [[ ${ipa_service:-} -ne 0 ]]; then
                error ${ipa_service:-} "Preflight: Unable to auth with ${auth_host}, please verify and retry"
            else
                debug echo "Preflight: Auth Host OK"
            fi
        else
            error 1 "unknown authentication host, please check and retry"
        fi
    }

    function check_user_exists() {
        ## check if the username and uid are in the db already

        _authserver_=${1:-}
        ## test the user exists in some way already
        local same_user=$(/usr/bin/ssh ${_authserver_} "(/usr/bin/getent passwd ${_uid_} || echo 'none:') | /usr/bin/cut -f1 -d':' || echo none" 2>/dev/null || echo 'none')
        if [[ ${same_user} == ${_username_} ]]; then
            # this user is already in the directory correctly
            return 5
        fi

        local uid_output=$(/usr/bin/ssh ${_authserver_} "/usr/bin/getent passwd ${_uid_} >/dev/null; echo \$?" 2>/dev/null || echo $?)
        local name_output=$(/usr/bin/ssh ${_authserver_} "/usr/bin/getent passwd ${_username_} >/dev/null; echo \$?" 2>/dev/null || echo $?)

        if [[ ${uid_output} == '0' ]]; then
            #uid is taken
            return 10
        elif [[ ${name_output} == '0' ]]; then
            #username is taken
            return 20
        fi

        if [[ ${uid_output} == '2' ]] && [[ ${name_output} == '2' ]]; then
            #uid and username are not taken yet
            return 0
        else
            #unknown error
            max=$(( uid_output > name_output ? uid_output : name_output ))
            return ${max}
        fi
    }

    ## try to access remote servers to ensure they're up:
    for host_checked in ${ssh_hosts[@]}; do
        debug echo "Preflight: testing connection to ${host_checked}";

        local host_ip=$(resolve_hostname "${host_checked}.${_GLOBALS_['domain_url']}")
        debug echo "Preflight: Found IP for host ${host_checked} is ${host_ip}"

        local host_status=$(ssh ${host_ip} "hostname" 2>/dev/null 1>/dev/null && echo $? || echo $?)
        if [[ ${host_status:-} -ne 0 ]]; then
            error ${host_status:-} "Preflight: Unable to connect to host ${host_checked}, please verify and retry"
        else
            debug echo "Preflight: Host OK"
        fi
    done

    for host_checked in ${slurm_hosts[@]}; do
        debug echo "Preflight: Testing Slurm running on ${host_checked}"

        local host_ip=$(resolve_hostname "${host_checked}.${_GLOBALS_['domain_url']}")
        debug echo "Preflight: Found IP for host ${host_checked} is ${host_ip}"

        local sacctmgr="${slurm_prefix_dict[${host_checked}]}sacctmgr"
        local host_status=$(/usr/bin/ssh ${host_ip} "${sacctmgr} list users --parsable2" 2>/dev/null 1>/dev/null && echo $? || echo $?)
        if [[ ${host_status:-} -ne 0 ]]; then
            error ${host_status:-} "Preflight: Error calling ${sacctmgr} on host ${host_checked}, please verify and retry"
        else
            debug echo "Preflight: Slurm Host OK"
        fi
    done

    for host_checked in ${auth_hosts[@]}; do
        do_auth_host ${host_checked}
    done

    for host_checked in ${auth_hosts[@]}; do
        user_exists=$(check_user_exists ${host_checked} && echo $? || echo $?)
        if [[ ${user_exists} == '5' ]]; then
             _GLOBALS_["user_exists_${host_checked}"]=true
             debug echo "Preflight: user already exists in auth for server ${host_checked}, no need to recreate"
        elif [[ ${user_exists} == '10' ]]; then
            error 10 "Preflight: Error with username/uid mismatch: user uid ${_uid_} already exists for ${host_checked}"
        elif [[ ${user_exists} == '20' ]]; then
            error 20 "Preflight: Error with username/uid mismatch: username ${_username_} already exists for ${host_checked}"
        elif [[ ${user_exists} != '0' ]]; then
            error ${user_exists} "Preflight: Error with username/uid lookup: please check user existence and uid for ${host_checked}"
        else
            debug echo "Preflight: username and uid are both available (unclaimed) for server ${host_checked}"
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

if [[ ${EUID:-1} != 0 ]]; then
    error 2 "Please run this command as the root user on a system with ssh key root access to the ipa, nfs, and nis servers"
fi

if [[ -z ${_GLOBALS_['username']:-} ]]; then
    echo "Please specify a username for the new user"; usage
    error 1 "missing required option"
fi
if [[ -z ${_GLOBALS_['firstname']:-} ]]; then
    echo "Please specify the user's first name"; usage
    error 1 "missing required option"
fi
if [[ -z ${_GLOBALS_['lastname']:-} ]]; then
    echo "please specify the user's last name"; usage
    error 1 "missing required option"
fi
if [[ -z ${_GLOBALS_['emailaddr']:-} ]]; then
    echo "please specify the user's emailaddr name"; usage
    error 1 "missing required option"
fi

if [[ -z ${_GLOBALS_['next_uid']:-} ]]; then
    get_next_uid next_uid
fi

preflight

create_ipa_user
create_ipa_automounts
create_slurm_user asimov

create_nfs_mounts

## the script exits successfully
success
#___END___#