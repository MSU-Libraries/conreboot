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
##      Source: https://github.com/natecollins/cfgbackup
##      Licence: MIT

###############################
## Creates an array of config variables with default values
default_config() {
    declare -g -A CONFIG
    CONFIG[REBOOT_TIMES]=3am-7am
    CONFIG[PREVENT_PROCESSES]=
    CONFIG[PREVENT_ACTIVE_USERS]=0
    CONFIG[ACTIVE_USERS_MINUTES]=120
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
## BEGIN RUNNING coreboot.sh
#######################################
CONFIG_FILE=${1:-/etc/coreboot.cfg}

# TODO config file exists and is readable
