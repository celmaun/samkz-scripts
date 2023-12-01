#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2046

{ [ -n "${-##*i*}" ] && type com_samkz_fs_sh && return; } >/dev/null 2>&1

set -a

com_samkz_fs_sh() { :; }

orex() { "$@" || exit "$?$(>&2 printf   'ERROR[%d]: %s\n' "$?" "$*")"; }
oret() { "$@" || return "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "$*")"; }
quote() { printf '%s\n' "$1" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/" ; }

# ls
# -F Append indicator (one of */=@|) to entries
# / is a directory
# @ is a symlink
# | is a named pipe (fifo)
# = is a socket.
# * for executable files
# > is for a "door" -- a file type currently not implemented for Linux, but supported on Sun/Solaris.

match_files_sort_mtime() (
    dir="${1:-'.'}"; pattern="${2:-'.*'}"
    dir="${dir:?}"; pattern="${pattern:?}"

    orex cd -P "${dir:?}"
    # -r = reverse
    orex ls -AFt1 -r --color=never | \
    orex sed -e 's/\*$//g' -e '/[/@|=>]$/d' | \
    orex grep -E --color=never "^${pattern:?}\$" | \
    orex xargs -r readlink -f --
) 

match_files_sort_mtime_desc() (
    dir="${1:-'.'}"; pattern="${2:-'.*'}"
    dir="${dir:?}"; pattern="${pattern:?}"

    orex cd -P "${dir:?}"
    orex ls -AFt1 --color=never | \
    orex sed -e 's/\*$//g' -e '/[/@|=>]$/d' | \
    orex grep -E --color=never "^${pattern:?}\$" | \
    orex xargs -r readlink -f --
) 

set +a
