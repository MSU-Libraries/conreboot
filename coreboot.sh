#!/bin/bash
#######################################
## Conditional Reboot
#######################################
##
## Usage:
##   Reboot based on CONFIG file
##      coreboot.sh CONFIG
##
##   Reboot based on /etc/coreboot.cfg
##      coreboot.sh
##
## If config file is missing or invalid,
## nothing happens and script exits with code 1
##

#######################################
## Enable debug messages by setting DEBUG. E.g.
##    DEBUG=1 ./coreboot.sh
_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "$@"
    fi
}

#######################################
## PARSE CONFIG FILE
#######################################
## Credit: Config file parsing and loading derived from cfgbackup
## Source: https://github.com/natecollins/cfgbackup
## Licence: MIT

###############################
## Creates an array of config variables with default values
default_config() {
    declare -g -A CONFIG
    CONFIG[REBOOT_TIMES]=3am-7am
    CONFIG[PREVENT_PROCESSES]=
    CONFIG[PREVENT_ACTIVE_USERS]=0
    CONFIG[ACTIVE_USERS_MINUTES]=120
    CONFIG[SHUTDOWN_TIME]="+1"
    CONFIG[DELAY_UNTIL_OKAY]=0
}

###############################
## Parse a value for a given config line
##  $1 -> File to search
##  $2 -> Name of parameter to get value for
## Prints the string value, or empty string if not found
config_param_get() {
    grep -E "^ *$2 *=" $1 | tail -n 1 | cut -d= -f2- | sed 's/ *$//' | sed 's/^ *//'
}

###############################
## Parse config to check if a given parameter exists
##  $1 -> File to search
##  $2 -> Name of parameter to get value for
## Returns 0 if the parameter exists in the file, 1 if it does not
config_param_exists() {
    PARAM_FOUND=$( grep -E "^ *$2 *=" $1 )
    if [[ $PARAM_FOUND != "" ]]; then
        return 0
    fi
    return 1
}

###############################
## Check if array contains a given value
##  $1 -> Name of array to search
##  $2 -> Value to find
## Returns 0 if an element matches the value to find
array_contains() {
    local ARRNAME=$1[@]
    local HAYSTACK=( ${!ARRNAME} )
    local NEEDLE="$2"
    for VAL in "${HAYSTACK[@]}"; do
        if [[ $NEEDLE == $VAL ]]; then
            return 0
        fi
    done
    return 1
}

###############################
## Parse config file given
## Returns 0 on success, 1 on error
## Any errors will be in PARSE_ERRORS
parse_config() {
    declare -a PARSE_ERRORS
    default_config
    # Setting these to empty is allowed and the empty value will override the default value
    ALLOWED_EMPTY=( PREVENT_PROCESSES )

    _debug "Attempting load of config: ${CONFIG_FILE}"
    # Verify config file exists and is readable
    if [[ ! -f $CONFIG_FILE || ! -r $CONFIG_FILE ]]; then
        PARSE_ERRORS+=("Config file doesn't exist or isn't readable.")
    else
        # Parse config file for variables
        for KEY in "${!CONFIG[@]}"; do
            # Get variable values from config file
            CONFIG_VALUE=$(config_param_get $CONFIG_FILE $KEY)
            # If key is allowed to have an empty value, then do not set the default value
            if array_contains ALLOWED_EMPTY "$KEY" && config_param_exists $CONFIG_FILE $KEY; then
                : # do nothing
            # If value is empty, leave as default
            elif [[ $CONFIG_VALUE == "" ]]; then
                CONFIG_VALUE=${CONFIG[$KEY]}
            fi
            # Update CONFIG values
            CONFIG[$KEY]=$CONFIG_VALUE

            _debug "Loaded from config: ${KEY}=${CONFIG_VALUE}"
        done
    fi

    if [[ ${#PARSE_ERRORS[@]} -ne 0 ]]; then
        echo "ERROR: Could not parse config file: $CONFIG_FILE"
        for PARSE_MSG in "${PARSE_ERRORS[@]}"; do
            echo $PARSE_MSG
        done
        exit 1
    fi
}

#######################################
## REBOOT TEST CONDITIONS
#######################################

declare -r TIME_REGEX="([0-9]{1,2})(:([0-9]{2}))?([ap])m"

time_to_minutes() {
    local HOURS MINUTES AFTERNOON

    if ! [[ $1 =~ ^$TIME_REGEX$ ]]; then
        echo "Bad time: ${1@Q}" >&2
        exit 1
    fi

    HOURS=${BASH_REMATCH[1]}
    ((HOURS == 12)) && HOURS=0
    MINUTES=${BASH_REMATCH[3]:-0}
    AFTERNOON=$([[ ${BASH_REMATCH[4]} == p ]] && echo 12 || echo 0)

    echo $((60 * HOURS + 60 * AFTERNOON + MINUTES))
}

is_reboot_time() {
    local TIME_PERIODS PERIOD RANGE_START RANGE_END NOW
    IS_REBOOT_TIME=1
    IFS=',' read -ra TIME_PERIODS <<< "${CONFIG[REBOOT_TIMES]}"
    for PERIOD in "${TIME_PERIODS[@]}"; do
        if ! [[ $PERIOD =~ ^${TIME_REGEX}-${TIME_REGEX}$ ]]; then
            echo "Bad time period: ${PERIOD@Q}." >&2
            exit 1
        fi
        RANGE_START=$(time_to_minutes "${PERIOD%-*}")
        RANGE_END=$(time_to_minutes "${PERIOD#*-}")
        NOW=$(date "+%H * 60 + %M" | perl -ne 'print eval $_;')
        if ((RANGE_START <= RANGE_END)); then
            ((RANGE_START <= NOW && NOW <= RANGE_END)) && IS_REBOOT_TIME=0
        else
            ((RANGE_START <= NOW || NOW <= RANGE_END)) && IS_REBOOT_TIME=0
        fi
    done
    _debug "Invalid reboot time? ${IS_REBOOT_TIME}"
    return ${IS_REBOOT_TIME}
}

no_prohibited_process() {
    PROC_FOUND=0
    IFS=',' read -ra PROC_LIST <<< "${CONFIG[PREVENT_PROCESSES]}"
    for PROC in "${PROC_LIST[@]}"; do
        pgrep -f "${PROC}"
        if [[ $? -eq 0 ]]; then
            PROC_FOUND=1
            break
        fi
    done
    _debug "Prohibited processes? ${PROC_FOUND}"
    return ${PROC_FOUND}
}

no_active_users() {
    STALE_TIMEOUT=${CONFIG[ACTIVE_USERS_MINUTES]:-120}
    # Return nonzero if any login session has been active in less than STALE
    # seconds. Note that this does not count X11 sessions
    SELF_TTY=$( tty | sed 's,/dev/,,' );    # Exclude TTY executing this script
    who -s | awk '{ print $2 }' |
        grep -v ${SELF_TTY} |
        (cd /dev && xargs -r -- stat -c %X --) |
        awk -v STALE=${STALE_TIMEOUT} -v NOW="$(date +%s)" '{ if (NOW - $1 < STALE) exit 1; }'
    NO_ACTIVE_USERS=$?
    _debug "Active users? ${NO_ACTIVE_USERS}"
    return ${NO_ACTIVE_USERS}
}

#######################################
## REBOOT TRIGGER FUNCTIONS
#######################################
check_reboot() {
    _debug "Checking if okay to issue reboot"
    if  is_reboot_time && \
        no_prohibited_process && \
        no_active_users; then
            _debug "All reboot checks passed!"
            REBOOT_OKAY=1
    fi
}

do_reboot() {
    declare -g REBOOT_OKAY
    REBOOT_OKAY=0
    check_reboot

    while [[ ${REBOOT_OKAY} -eq 0 && ${CONFIG[DELAY_UNTIL_OKAY]} -eq 1 ]]; do
        _debug "Sleeping for 1 minute"
        sleep 60
        check_reboot
    done

    if [[ ${REBOOT_OKAY} -eq 1 ]]; then
        _debug "Initiating reboot command: shutdown -h ${CONFIG[SHUTDOWN_TIME]}"
        shutdown -r ${CONFIG[SHUTDOWN_TIME]}
        # Triggered reboot
        exit 0
    fi
    # Failed to trigger reboot
    exit 1
}

#######################################
## BEGIN RUNNING coreboot.sh
#######################################
_debug "Debug enabled"
CONFIG_FILE=${1:-/etc/coreboot.cfg}
parse_config
do_reboot

