#!/bin/bash
#
# NAME
#        img2vcard.sh - Convert images to a vCard PHOTO property
#
# SYNOPSIS
#        img2vcard.sh [OPTION]... PATH...
#
# DESCRIPTION
#        By default resizes the images so they fit into a square 96x96 pixels
#        without cropping, which is the standard for Gmail. Then base64 encodes
#        them, adds the vCard property specification, and wraps the lines to be
#        valid according to the RFC 2426 (vCard 3.0) specification.
#
#        The output contains the correct \r\n line separator used by the vCard
#        standard
#
#        The result can be validated with the vCard module
#        <https://github.com/l0b0/vCard-module>.
#
#        -r WIDTHxHEIGHT, --resize=WIDTHxHEIGHT
#               Resize to WIDTH by HEIGHT pixels, instead of the default 96 by
#               96.
#
#        -R, --no-resize
#               Don't resize images.
#
#        -h, --help
#               Output this documentation.
#
#        -v, --verbose
#               Verbose output
#
# EXAMPLES
#    img2vcard.sh *.jpg
#        Outputs vCard PHOTO properties for all the images in 96x96 format.
#
#    img2vcard.sh -R jdoe.gif
#        Convert jdoe.gif without resizing it.
#
# BUGS
#    https://github.com/l0b0/img2vcard/issues
#
# COPYRIGHT AND LICENSE
#    Copyright (C) 2011 Victor Engmark
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
################################################################################

set -o errexit
set -o nounset
set -o noclobber

# Exit codes from /usr/include/sysexits.h, as recommended by
# http://www.faqs.org/docs/abs/HTML/exitcodes.html
EX_USAGE=64

# Custom errors
EX_UNKNOWN=1

cmdname="$(basename -- "$0")"

warning()
{
    # Output warning messages
    # Color the output red if it's an interactive terminal
    # @param $1...: Messages

    test -t 1 && tput setf 4

    printf '%s\n' "$@" >&2

    test -t 1 && tput sgr0 # Reset terminal
}

error()
{
    # Output error messages with optional exit code
    # @param $1...: Messages
    # @param $N: Exit code (optional)

    local -a messages=( "$@" )

    # If the last parameter is a number, it's not part of the messages
    local -r last_parameter="${@: -1}"
    if [[ "$last_parameter" =~ ^[0-9]*$ ]]
    then
        local -r exit_code=$last_parameter
        unset messages[$((${#messages[@]} - 1))]
    fi

    warning "${messages[@]}"

    exit ${exit_code:-$EX_UNKNOWN}
}

usage()
{
    # Print documentation until the first empty line
    # @param $1: Exit code (optional)
    local line
    while IFS= read line
    do
        if [ -z "$line" ]
        then
            exit ${1:-0}
        elif [ "${line:0:2}" == '#!' ]
        then
            # Shebang line
            continue
        fi
        echo "${line:2}" # Remove comment characters
    done < "$0"
}

verbose_echo()
{
    # @param $1: Optionally '-n' for echo to output without newline
    # @param $(1|2)...: Messages
    if [ "${verbose-}" ]
    then
        if [ "$1" = "-n" ]
        then
            $newline='-n'
            shift
        fi

        while [ -n "${1:-}" ]
        do
            echo -e ${newline:-} "$1" >&2
            shift
        done
    fi
}

params="$(getopt -o r:Rhv -l resize:,no-resize,help,verbose \
    --name "$cmdname" -- "$@")"

if [ $? -ne 0 ]
then
    usage $EX_USAGE
fi

eval set -- "$params"

# Defaults
dimensions=96x96

while true
do
    case $1 in
        -r|--resize)
            dimensions="$2"
            shift 2
            ;;
        -R|--no-resize)
            unset dimensions
            shift
            ;;
        -h|--help)
            usage
            exit
            ;;
        -v|--verbose)
            verbose='--verbose'
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            usage
            ;;
    esac
done

if [ $# -eq 0 ]
then
    usage $EX_USAGE
fi

resize()
{
    # Only if necessary
    if [ "${dimensions+string}" = string ]
    then
        verbose_echo "Resizing to $dimensions"
        convert -resize "$dimensions" "$1" :-
    else
        cat -- "$1"
    fi
}

for path
do
    verbose_echo "Processing $path"
    if [ ! -f "$path" ]
    then
        warning "${cmdname}: cannot access ${path}: No such file"
        continue
    fi

    format="$(identify -format %m -- "$path")"

    photo="PHOTO;TYPE=${format,,};ENCODING=b:$(resize "$path" | base64 -w 0)"
    printf "${photo:0:75}\r\n"
    printf "${photo:75}" | fold -w 74 | sed -e 's/^/ /' -e 's/$/\r/'
    printf '\n'
done
