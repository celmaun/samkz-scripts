#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2046

{ type com_samkz_utils_sh && return; } >/dev/null 2>&1

set -a

com_samkz_utils_sh() { :; }

orex() { "$@" || exit "$?$(>&2 printf   'ERROR[%d]: %s\n' "$?" "$*")"; }
oret() { "$@" || return "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "$*")"; }
quote() { printf '%s\n' "$1" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/" ; }

canon_file() { [ -n "$1" ] && [ -f "$1" ] && readlink -f -- "$1"; }
canon_dir() { [ -n "$1" ] && [ -d "$1" ] && readlink -f -- "$1"; }
canon_exe() { [ -n "$1" ] && [ -f "$1" ] && [ -x "$1" ] && readlink -f -- "$1"; }


is_binary() { [ -f "${1-}" ] || return; case "$(orex file "${1:?}")" in (*executable*) return 0;; esac; return 1; }
is_shell_script() { [ -f "${1-}" ] || return; case "$(orex file "${1:?}")" in (*shell*script*) return 0;; esac; return 1; }
is_shell_program() { [ -f "${1-}" ] && [ -x "$1" ] || return; case "$(orex file "${1:?}")" in (*shell*script*) return 0;; esac; return 1; }

get_home() ( u="$(id -urn "$@")" && eval "h=~${u:?}" && printf '%s\n' "${h:?}"; )

file_user() { [ -e "$1" ] && (x="$(command ls -ld "$1")" || exit; set -f -- ${x:?} || exit; user="${3-}"; id -urn "${user:?}"); }
file_group() { [ -e "$1" ] && (x="$(command ls -ld "$1")" || exit; set -f -- ${x:?} || exit; group="${4-}"; printf '%s\n' "${group:?}"); }
file_user_colon_group() { [ -e "$1" ] && (x="$(command ls -ld "$1")" || exit; set -f -- ${x:?} || exit; user="${3-}"; group="${4-}"; printf '%s:%s\n' "$(id -urn "${user:?}")" "${group:?}"); }

get_super_group() { if [ "$(uname -s)" = Darwin ]; then printf '%s\n' 'staff'; else printf '%s\n' 'sudo'; fi; }

local_user_owner() {
  [ "$(id -ur)" -eq 0 ] || return 0

  [ -e "$1" ] || return

  x="$(orex readlink -f -- "$1")" || return

  if [ -d "$x" ]; then
      oret chown -R "${LOCAL__USER:?}:" "$x" || return
      return
  fi

  oret chown "${LOCAL__USER:?}:" "$x" || return
}

samkz__chown() (
  file="$1"; : "${file:?}"

  [ "$(id -ur)" -eq 0 ] || return 0

  ${LOCAL__USER:+:} samkz__local_user_export

  orex chown "${LOCAL__USER:?}:" "${file:?}"
)

samkz__print_env_prefixed() (
  { builtin shopt -so posix ||:; }>/dev/null 2>&1
  export -p | sed -E -n "s/^export ($(IFS='|'; printf %s "$*"))/\1/p"
)

samkz__create_env_file() (
  ${LOCAL__ETC:+:} samkz__local_user_export
  orex [ -d "${LOCAL__ETC:?}" ]

  program="$1"; : "${program:?}"
  env_file="${2:-"${LOCAL__ETC:?}/${program:?}.env"}"

  prefix=
  case "$program" in
    (user) {  samkz__local_user_export;  prefix=LOCAL__; };;
    (nginx) {   samkz__nginx__setup; prefix=MAIN__NGINX__; };;
    (letsencrypt) { samkz__letsencrypt__export;  prefix=MAIN__LETSENCRYPT__; };;
    (caddy) { samkz__caddy__setup; prefix=MAIN__CADDY__;  };;
  esac

  : "${prefix:?"Invalid program '$program'. Valid values: user, nginx, letsencrypt, caddy"}"

  samkz__print_env_prefixed "${prefix:?}" | sort -uo "${env_file:?}"
  samkz__chown "${env_file:?}"
)

samkz__import_env() {
  program="$1"; : "${program:?}"
  env_file="${LOCAL__ETC:-"$(samkz__local_user_export && printf '%s\n' "${LOCAL__ETC:?}")"}/${program:?}.env"

  if [ -f "$env_file" ]; then :; else
    samkz__create_env_file "$program"
  fi

  orex [ -f "$env_file" ]

  set -a; orex . "$env_file"; set +a

  unset program env_file
}

samkz__local_user() {
    set +e -u

    u=
    for _ in _; do
      u="$(id -urn)"; [ -z "${u##root}" ] || break
      u="$(id -un)"; [ -z "${u##root}" ] || break
      u="$(logname)"; [ -z "${u##root}" ] || break
      u="$(who am i)"; u="${u%% *}"; [ -z "${u##root}" ] || break
      u="${SUDO_USER:-}"; [ -z "${u##root}" ] || break
    done

    [ -n "${u##root}" ] && printf '%s\n' "${u:?}" && exit

    # set -- "${BASH_SOURCE-}" "${0-}" "${HOME-}" "$PWD"

    for f in "${BASH_SOURCE-}" "${0-}" "${HOME-}" "$PWD"; do
      u="$(file_user "$f")" && [ -n "${u##root}" ] && id -urn "${u:?}" && exit
    done

    exit "1$(>&2 printf '%s\n' "Unable to find non-root user")"
}

samkz__local_user_export() {
    set -a
    LOCAL__USER="$(id -urn)"
    [ -n "${LOCAL__USER##root}" ] || LOCAL__USER="$(samkz__local_user)"
    LOCAL__GROUP="$(id -grn "${LOCAL__USER:?}")"
    LOCAL__UID="$(id -ur "${LOCAL__USER:?}")"
    LOCAL__EUID="$(id -u "${LOCAL__USER:?}")"
    LOCAL__GID="$(id -gr "${LOCAL__USER:?}")"
    LOCAL__EGID="$(id -g "${LOCAL__USER:?}")"
    eval "LOCAL__HOME=~${LOCAL__USER:?}"; export LOCAL__HOME
    LOCAL__ETC="${LOCAL__HOME:?}/.config"
    set +a
    [ -d "$LOCAL__ETC" ] || { mkdir "$LOCAL__ETC"; [ "$(id -ur)" -gt 0 ] || chown "$LOCAL__USER:" "$LOCAL__ETC"; }

    ${LOCAL__BIN:+:} samkz__local_user_bin_export
}

samkz__local_user_bin_export() {
    ${LOCAL__USER:+:} samkz__local_user_export

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
