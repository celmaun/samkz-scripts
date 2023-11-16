#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317


set -a


orex() { "$@" || exit "$?$(>&2 printf   'ERROR[%d]: %s\n' "$?" "$*")"; }
oret() { "$@" || return "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "$*")"; }
quote() { printf '%s\n' "$1" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/" ; }

canon_file() { [ -n "$1" ] && [ -f "$1" ] && readlink -f -- "$1"; }
canon_dir() { [ -n "$1" ] && [ -d "$1" ] && readlink -f -- "$1"; }
canon_exe() { [ -n "$1" ] && [ -f "$1" ] && [ -x "$1" ] && readlink -f -- "$1"; }

print__LOCAL__USER() {
    set +e -u

    file_user() { [ -e "$1" ] && x="$(command ls -ld "$1")" && x="${x#* * }" && x="${x%% *}" && [ -n "$x" ] && id -urn "$x"; }

    set -- "$(id -urn)" "$(id -un)" "${APPCON__USER__ADMIN-}" "${SUDO_USER-}"
    for u; do [ -n "${u##root}" ] && id -urn "${u:?}" && exit; done
    set -- "${BASH_SOURCE-}" "${0-}" "$PWD"
    for f; do u="$(file_user "$f")" && [ -n "${u##root}" ] && id -urn "${u:?}" && exit; done

    exit "1$(>&2 printf '%s\n' "Unable to find non-root user")"
}

export__LOCAL__USER() {
    set -a
    LOCAL__USER="$(id -urn)"
    [ -n "${LOCAL__USER##root}" ] || LOCAL__USER="$(print__LOCAL__USER)"
    LOCAL__GROUP="$(id -grn "${LOCAL__USER:?}")"
    LOCAL__UID="$(id -ur "${LOCAL__USER:?}")"
    LOCAL__EUID="$(id -u "${LOCAL__USER:?}")"
    LOCAL__GID="$(id -gr "${LOCAL__USER:?}")"
    LOCAL__EGID="$(id -g "${LOCAL__USER:?}")"
    eval "LOCAL__HOME=~${LOCAL__USER:?}"
    set +a
    
    export__LOCAL__BIN
}

export__LOCAL__BIN() {
    [ -d "${LOCAL__HOME-}" ] || export__LOCAL__USER
    LOCAL__BIN="${LOCAL__BIN:-"$(
        set -- 'bin' '.bin' '.local/bin'
        for d; do 
            d="${LOCAL__HOME:?}/$d"
            case ":$PATH:" in (*:"$d":*) { printf %s "$d"; exit; };; esac; 
        done
    )"}"
    LOCAL__BIN="${LOCAL__BIN:-"${LOCAL__HOME:?}/bin"}"; export LOCAL__BIN
    orex mkdir -p "$LOCAL__BIN"
    case ":$PATH:" in (*:"${LOCAL__BIN:?}":*);; (*) PATH="${LOCAL__BIN:?}${PATH:+:$PATH}";; esac
}


 set +a  