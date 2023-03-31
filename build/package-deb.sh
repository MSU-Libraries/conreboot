#!/bin/bash
set -e

SCRIPT_NAME=$( basename $0 )
# Search for VERSION=XYX in VERSION_FILE (file relative to SRC_DIR)
VERSION_FILE=conreboot

runhelp() {
    echo ""
    echo "Usage: $SCRIPT_NAME [FLAGS]"
    echo ""
    echo "    Build .deb package from project source."
    echo ""
    echo "FLAGS:"
    echo "  -n|--builder-name NAME"
    echo "      Name of who is building the package (will prompt if not provided)."
    echo "  -e|--builder-email EMAIL"
    echo "      Address of who is building the package (will prompt if not provided)."
    echo "  -r|--release RELEASE"
    echo "      Release for this build (appended to version). Default: 0"
    echo "  -y|--yes"
    echo "      Do not prompt for confirmation."
    echo "  -q|--quiet"
    echo "      Only output final package path once completed (implies -y, requires -n -e)."
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

declare_vars() {
    declare -g VERBOSE=1
    declare -g VFLAG=v
    declare -g YES=0
    declare -x -g PKGBLD_NAME=
    declare -x -g PKGBLD_EMAIL=
    declare -x -g PKGBLD_DATE=$( date )
    declare -x -g PKGBLD_INSTALL_SIZE=0
    declare -g RELEASE=0
    declare -g DEB_FILE
    declare -g BLD_DIR=$( readlink -f $( dirname "${BASH_SOURCE[0]}" ))
    declare -g SRC_DIR=$( dirname "$BLD_DIR" )
    declare -g DIST_DIR="${BLD_DIR}/dist"
    declare -g TMPL_DIR="${BLD_DIR}/templates"
    declare -x -g PKG_NAME=$( basename "$SRC_DIR" )
    declare -x -g VERSION=$( config_param_get "${SRC_DIR}/${VERSION_FILE}" "VERSION" )
    mkdir -p "$DIST_DIR"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -q|--quiet)
            VERBOSE=0
            VFLAG=
            shift ;;
        -y|--yes)
            YES=1
            shift ;;
        -n|--builder-name)
            PKGBLD_NAME="$2"
            shift; shift ;;
        -e|--builder-email)
            PKGBLD_EMAIL="$2"
            shift; shift ;;
        -r|--release)
            RELEASE="$2"
            shift; shift ;;
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
        if [[ "$VERBOSE" -eq 0 ]]; then
            echo "Using --quiet flag requires passing --builder-name also."
            exit 1
        fi
        echo "Enter your full name to be included as package builder:"
        read -p "> " PKGBLD_NAME
    done

    while [[ -z "$PKGBLD_EMAIL" ]]; do
        if [[ "$VERBOSE" -eq 0 ]]; then
            echo "Using --quiet flag requires passing --builder-email also."
            exit 1
        fi
        echo "Enter your email to be included as package builder contact:"
        read -p "> " PKGBLD_EMAIL
    done

    if [[ -n "$RELEASE" ]]; then
        RELEASE_POST="-${RELEASE}"
    fi
    DEB_FILE="${PKG_NAME}-${VERSION}${RELEASE_POST}.deb"

    verbose ""
    verbose "Project:      $PKG_NAME"
    verbose "Builder:      $PKGBLD_NAME"
    verbose "Email:        $PKGBLD_EMAIL"
    verbose "Version:      $VERSION"
    verbose "Release:      $RELEASE"
    verbose "Package:      $DEB_FILE"
    verbose "Source:       $SRC_DIR"
    verbose "Build:        $BLD_DIR"
    verbose "Dist:         $DIST_DIR"
    verbose "Templates:    $TMPL_DIR"
    verbose ""
    if [[ "$YES" -ne 1 && "$VERBOSE" -eq 1 ]]; then
        read -p "Is this correct (y/n)? " CONFIRM_PRMPT
        if [[ "${CONFIRM_PRMPT,,}" != "y" ]]; then
            echo "Re-run build script to try again."
            exit 1
        fi
    fi
}

build_data() {
    verbose "Creating data.tar.gz..."
    mkdir -p                            "$DIST_DIR/data/usr/sbin"
    cp "$SRC_DIR/conreboot"             "$DIST_DIR/data/usr/sbin/conreboot"
    chmod -w                            "$DIST_DIR/data/usr/sbin"
    mkdir -p                            "$DIST_DIR/data/usr/share/doc/conreboot"
    cp "$SRC_DIR/conreboot.cfg.example" "$DIST_DIR/data/usr/share/doc/conreboot/conreboot.cfg"
    cp "$SRC_DIR/README.md"             "$DIST_DIR/data/usr/share/doc/conreboot/README.md"
    envsubst < "$TMPL_DIR/copyright"  > "$DIST_DIR/data/usr/share/doc/conreboot/copyright" 
    cat "$SRC_DIR/LICENSE"           >> "$DIST_DIR/data/usr/share/doc/conreboot/copyright"
    mkdir -p                            "$DIST_DIR/data/usr/share/man/man1"
    cp "$SRC_DIR/man.conreboot.1"       "$DIST_DIR/data/usr/share/man/man1/conreboot.1"
    gzip -f                             "$DIST_DIR/data/usr/share/man/man1/conreboot.1"
    mkdir -p                            "$DIST_DIR/data/etc/bash_completion.d"
    cp "$SRC_DIR/auto_conreboot.bash"   "$DIST_DIR/data/etc/bash_completion.d/conreboot"
    mkdir -p                            "$DIST_DIR/data/etc/systemd/system"
    chmod 750                           "$DIST_DIR/data/etc/systemd/system"
    cp "$SRC_DIR/conreboot.service"     "$DIST_DIR/data/etc/systemd/system/conreboot.service"
    cp "$SRC_DIR/conreboot.timer"       "$DIST_DIR/data/etc/systemd/system/conreboot.timer"
    chmod -w                            "$DIST_DIR/data"
    cd                                  "$DIST_DIR/data"
    tar -cz${VFLAG}f ../data.tar.gz ./
}

build_control() {
    verbose "Creating control.tar.gz..."
    cd                                  "$DIST_DIR/data"
    PKGBLD_INSTALL_SIZE=$( du -sb "$DIST_DIR/data" | awk '{ print $1 }' )
    mkdir -p                            "$DIST_DIR/control"
    find . -type f -exec md5sum {} \; > "$DIST_DIR/control/md5sum"
    envsubst < "$TMPL_DIR/control"    > "$DIST_DIR/control/control"
    cp "$TMPL_DIR/postinst"             "$DIST_DIR/control/postinst"
    chmod +x                            "$DIST_DIR/control/postinst"
    cp "$TMPL_DIR/postrm"               "$DIST_DIR/control/postrm"
    chmod +x                            "$DIST_DIR/control/postrm"
    cp "$TMPL_DIR/prerm"                "$DIST_DIR/control/prerm"
    chmod +x                            "$DIST_DIR/control/prerm"
    cd                                  "$DIST_DIR/control"
    tar -cz${VFLAG}f ../control.tar.gz ./
}

make_archive() {
    verbose "Creating archive..."
    cp "$TMPL_DIR/debian-binary" "$DIST_DIR/"
    cd "$DIST_DIR"
    if [[ "$VERBOSE" -eq 0 ]]; then
        ar r "$DEB_FILE" debian-binary control.tar.gz data.tar.gz 2> /dev/null
    else
        ar vr "$DEB_FILE" debian-binary control.tar.gz data.tar.gz
    fi
    cleanup
    verbose "Package created:"
    echo "$DIST_DIR/$DEB_FILE"
}

cleanup() {
    verbose "Cleaning up..."
    rm -r "$DIST_DIR/data"
    rm -r "$DIST_DIR/control"
    rm "$DIST_DIR/control.tar.gz"
    rm "$DIST_DIR/data.tar.gz"
    rm "$DIST_DIR/debian-binary"
}

verify_command_exists "envsubst"
verify_command_exists "ar"
verify_command_exists "gzip"
declare_vars
parse_args "$@"
builder_info
build_data
build_control
make_archive
