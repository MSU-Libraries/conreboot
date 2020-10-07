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
    CONFIG[RANDOM_DELAY]=0
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
is_reboot_time() {
    IS_REBOOT_TIME=1
    IFS=',' read -ra TIME_PERIODS <<< "${CONFIG[REBOOT_TIMES]}"
    for PERIOD in "${TIME_PERIODS[@]}"; do
        # TODO check if NOW is within PERIOD (being e.g. "11:30pm-6am")
        if "TODO"; then
            IS_REBOOT_TIME=0
            break
        fi
    done
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
    return ${PROC_FOUND}
}

no_active_users() {
    STALE_TIMEOUT=${CONFIG[ACTIVE_USERS_MINUTES]:-120}
    # Return nonzero if any login session has been active in less than STALE
    # seconds. Note that this does not count X11 sessions.
    who -s | awk '{ print $2 }' |
        (cd /dev && xargs -r -- stat -c %X --) |
        awk -v STALE=${STALE_TIMEOUT} -v NOW="$(date +%s)" '{ if (NOW - $1 < STALE) exit 1; }'
    return $?
}

#######################################
## REBOOT TRIGGER FUNCTIONS
#######################################
check_reboot() {
    if  is_reboot_time && \
        no_prohibited_process && \
        no_active_users; then
            REBOOT_OKAY=1
    fi
}

do_reboot() {
    declare -g REBOOT_OKAY
    REBOOT_OKAY=0
    check_reboot

    while [[ ${REBOOT_OKAY} -eq 0 && ${CONFIG_FILE[$DELAY_UNTIL_OKAY]} -eq 1 ]]; do
        sleep 60
        check_reboot
    done

    if [[ ${REBOOT_OKAY} -eq 1 ]]; then
        shutdown -h ${CONFIG[SHUTDOWN_TIME]}
        # Triggered reboot
        exit 0
    fi
    # Failed to trigger reboot
    exit 1
}

#######################################
## BEGIN RUNNING coreboot.sh
#######################################
CONFIG_FILE=${1:-/etc/coreboot.cfg}
parse_config
do_reboot

