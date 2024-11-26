#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2046

#{ [ -n "${-##*i*}" ] && type com_samkz_fs_sh && return; } >/dev/null 2>&1

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

 # -type c
 #  File is of type c:
 #  b      block (buffered) special
 #  c      character (unbuffered) special
 #  d      directory
 #  p      named pipe (FIFO)
 #  f      regular file
 #  l      symbolic link; this is never true if the -L option
 #         or the -follow option is in effect, unless the
 #         symbolic link is broken.  If you want to search for
 #         symbolic links when -L is in effect, use -xtype.
 #  s      socket
 #  D      door (Solaris)
 #  To search for more than one type at once, you can supply
 #  the combined list of type letters separated by a comma `,'
 #  (GNU extension).


_match_files_sort_mtime() {
    _samkz__mfsm_ls_opts="${_samkz__mfsm_ls_opts:-"-1AFt"}"


    dir="${1:-"."}"; tp="${2:-"f"}"; pattern="${3:-".*"}"
    dir="${dir:?}"; tp="${tp:?}"; pattern="${pattern:?}"

    tp="$(set -f -- $tp; printf %s "$*")"
    tp="${tp:-"f"}"
    tt=""
    [ -n "${tp##*"f"*}" ] || tt="${tt:+"$tt ||"} [ -f % ]"
    [ -n "${tp##*"d"*}" ] || tt="${tt:+"$tt ||"} [ -d % ]"
    [ -n "${tp##*"l"*}" ] || tt="${tt:+"$tt ||"} [ -L % ]"
    [ -n "${tp##*"p"*}" ] || tt="${tt:+"$tt ||"} [ -p % ]"
    [ -n "${tp##*"s"*}" ] || tt="${tt:+"$tt ||"} [ -S % ]"

    cmd="[ -n % ] && ( ${tt:?} ) && readlink -f -- % ;"

    orex cd -P "${dir:?}"
    orex ls --color=never "${_samkz__mfsm_ls_opts:-"1AFt"}" | \
    orex sed -e 's/[\*@]$//g' -e '/[/|=>]$/d' | \
    orex grep --color=never -e "^${pattern:?}\$" | \
    xargs -r -I % sh -c "$cmd"
}


# $1 = A directory path, usually just a dot
# $2 = File types
# $3 = An extended regex pattern, prewrapped with start/caret (^) and EOF/dollar ($)
match_files_sort_mtime() (
    export _samkz__mfsm_ls_opts="-1AFtr"
    _match_files_sort_mtime "$@"
)

match_files_sort_mtime_desc() (
    export _samkz__mfsm_ls_opts="-1AFt"
    _match_files_sort_mtime "$@"
)

set +a
