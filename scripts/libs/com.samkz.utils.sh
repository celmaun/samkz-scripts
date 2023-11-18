#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2046


set -a


orex() { "$@" || exit "$?$(>&2 printf   'ERROR[%d]: %s\n' "$?" "$*")"; }
oret() { "$@" || return "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "$*")"; }
quote() { printf '%s\n' "$1" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/" ; }

canon_file() { [ -n "$1" ] && [ -f "$1" ] && readlink -f -- "$1"; }
canon_dir() { [ -n "$1" ] && [ -d "$1" ] && readlink -f -- "$1"; }
canon_exe() { [ -n "$1" ] && [ -f "$1" ] && [ -x "$1" ] && readlink -f -- "$1"; }


is_binary() { [ -f "${1-}" ] || return; case "$(orex file "${1:?}")" in (*executable*) return 0;; esac; return 1; }
is_shell_script() { [ -f "${1-}" ] || return; case "$(orex file "${1:?}")" in (*shell*script*) return 0;; esac; return 1; }
is_shell_program() { [ -f "${1-}" ] && [ -x "$1" ] || return; case "$(orex file "${1:?}")" in (*shell*script*) return 0;; esac; return 1; }

file_user() { [ -e "$1" ] && (set -f -- $(command ls -ld "$1"); user="${3-}"; printf '%s\n' "${user:?}"); }
file_group() { [ -e "$1" ] && (set -f -- $(command ls -ld "$1"); group="${4-}"; printf '%s\n' "${group:?}"); }

user_colon_group() { [ -e "$1" ] && (set -f -- $(command ls -ld "$1"); user="${3-}"; group="${4-}"; printf '%s:%s\n' "${user:?}" "${group:?}"); }

print__LOCAL__USER() {
    set +e -u

    u=
    while :; do
      u="$(id -urn)"; [ -z "${u##root}" ] || break
      u="$(id -un)"; [ -z "${u##root}" ] || break
      u="$(logname)"; [ -z "${u##root}" ] || break
      u="$(who am i)"; u="${u%% *}"; [ -z "${u##root}" ] || break
      u="${SUDO_USER:-}"; [ -z "${u##root}" ] || break
    done

    [ -n "${u##root}" ] && printf '%s\n' "${u:?}" && exit

    set -- "${BASH_SOURCE-}" "${0-}" "${HOME-}" "$PWD"
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
    eval "LOCAL__HOME=~${LOCAL__USER:?}"; export LOCAL__HOME
    set +a
    
    ${LOCAL__BIN:+:} export__LOCAL__BIN
}

export__LOCAL__BIN() {
    ${LOCAL__USER:+:} export__LOCAL__USER

    LOCAL__BIN="$(
        set +a -u

        h="${LOCAL__HOME:?}"
        set -- "$h/bin" "$h/.bin" "$h/.local/bin"
        for d; do
            case ":$PATH:" in (*:"$d":*) { printf '%s\n' "$d" && exit; };; esac;
        done

        d="/usr/local/bin"
        [ "$(file_user "$d" ||:)" = "${LOCAL__USER:?}" ] && printf '%s\n' "$d" && exit

        d="/opt/homebrew/bin"
        [ "$(file_user "$d" ||:)" = "${LOCAL__USER:?}" ] && printf '%s\n' "$d" && exit
    )"

    LOCAL__BIN="${LOCAL__BIN:-"${LOCAL__HOME:?}/bin"}"; export LOCAL__BIN

    if [ -d "${LOCAL__BIN}" ]; then :; else
      orex mkdir -p "$LOCAL__BIN"
    fi

    if [ "$(file_user "${LOCAL__BIN:?}")" = "$LOCAL__USER" ]; then :; else
      orex chown "${LOCAL__USER:?}:" "${LOCAL__BIN:?}"
    fi

    case ":$PATH:" in (*:"${LOCAL__BIN:?}":*);; (*) PATH="${LOCAL__BIN:?}${PATH:+:$PATH}";; esac
}


 set +a  