#!/bin/bash

SCRIPT_NAME=$( basename $0 )

runhelp() {
    echo ""
    echo "Usage: $SCRIPT_NAME [FLAGS]"
    echo ""
    echo "    Build .deb package from project source."
    echo ""
    echo "FLAGS:"
    echo "  -v|--verbose"
    echo "      Display what is happening."
    echo "  -y|--yes"
    echo "      Do not prompt for confirmation."
    echo ""
}

if [[ $1 == "-h" || $1 == "--help" || $1 == "help" ]]; then
    runhelp
    exit 0
fi

verify_command_exists() {
    CMD="$1"
    if ! command -v "$CMD" > /dev/null; then
        echo "FAILURE! Command must be available to build: $CMD"
        exit 1
    fi
}

verify_command_exists "fakeroot"
if [[ "$EUID" -ne 0 ]]; then
    fakeroot "$0" "$@"
    exit $?
fi

###############################
## Parse a value for a given config line
##  $1 -> File to search
##  $2 -> Name of parameter to get value for
## Prints the string value, or empty string if not found
config_param_get() {
    grep -E "^ *$2 *=" $1 | tail -n 1 | cut -d= -f2- | sed 's/ *$//' | sed 's/^ *//'
}

# Set defaults
defaults() {
    declare -g VERBOSE=0
    declare -g YES=0
    declare -g PKGBLD_NAME=
    declare -g PKGBLD_EMAIL=
    declare -g PKGBLD_DATE=$( date )
    declare -g BLD_DIR=$( readlink -f $( dirname "${BASH_SOURCE[0]}" ))
    declare -g SRC_DIR=$( dirname "$BUILD_DIR" )
    declare -g DIST_DIR="${BLD_DIR}/dist"
    mkdir -p "$DIST_DIR"
    declare -g VERSION=$( config_param_get "$SRC_DIR/../conreboot" )
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -v|--verbose)
            VERBOSE=1
            shift ;;
        -y|--yes)
            YES=1
            shift ;;
        *)
            echo "ERROR: Unknown flag: $1"
            exit 1
        esac
    done
}

verbose() {
    MSG="$1"
    if [[ "$VERBOSE" -eq 1 ]]; then
        2>&1 echo "${MSG}"
    fi
}

###############################
# Prompt for builder info if none was provided
builder_info() {
    while [[ -z "$PKGBLD_NAME" ]]; do
        echo "Enter your full name to be included as package builder:"
        read -p "> " PKGBLD_NAME
    done

    while [[ -z "$PKGBLD_EMAIL" ]]; do
        echo "Enter your email to be included as package builder contact:"
        read -p "> " PKGBLD_EMAIL
    done

    echo
    echo "Name:  $PKGBLD_NAME"
    echo "Email: $PKGBLD_EMAIL"
    echo
    if [[ "$YES" -ne 1 ]]; then
        read -p "Is this correct (y/n)? " CONFIRM_PRMPT
        if [[ "${CONFIRM_PRMPT,,}" != "y" ]]; then
            echo "Re-run build script to try again."
            exit 0
        fi
    fi
}

verify_command_exists "envsubst"
verify_command_exists "ar"
verify_command_exists "gzip"
defaults
parse_args
builder_info
