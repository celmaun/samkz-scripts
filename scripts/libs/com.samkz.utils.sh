#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2046

{ [ -n "${-##*i*}" ] && type com_samkz_utils_sh && return; } >/dev/null 2>&1

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

get_home() ( u="$(get_user "${1-}")" && eval "h=~${u:?}" && printf '%s\n' "${h:?}"; )

get_user() (
  if [ "${1:--}" = '-' ]; then
    id -urn; exit;
  fi
  orex id -urn "${1:?}"
 )

file_user() { [ -e "$1" ] && (x="$(command ls -ld "$1")" || exit; set -f -- ${x:?} || exit; user="${3-}"; id -urn "${user:?}"); }
file_group() { [ -e "$1" ] && (x="$(command ls -ld "$1")" || exit; set -f -- ${x:?} || exit; group="${4-}"; printf '%s\n' "${group:?}"); }
file_user_colon_group() { [ -e "$1" ] && (x="$(command ls -ld "$1")" || exit; set -f -- ${x:?} || exit; user="${3-}"; group="${4-}"; printf '%s:%s\n' "$(id -urn "${user:?}")" "${group:?}"); }

get_super_group() { if [ "$(uname -s)" = Darwin ]; then printf '%s\n' 'staff'; else printf '%s\n' 'sudo'; fi; }

is_darwin() {
    set -a
    case "$(uname -s)" in
        (*[Dd]arwin*) { is_darwin() { true; }; };;
        (*) { is_darwin() { false; }; };;
    esac
    set +a

    is_darwin
}

is_linux() {
    set -a
    case "$(uname -s)" in
        (*[Ll]inux*) { is_linux() { true; }; };;
        (*) { is_linux() { false; }; };;
    esac
    set +a

    is_linux
}

is_windows() { ! (is_linux && is_macos); }

is_macos() {
    set -a
    case "$(uname -s)" in
        (*[Dd]arwin*) { is_macos() { true; }; };;
        (*) { is_macos() { false; }; };;
    esac
    set +a

    is_macos
}

is_arm64() {
    set -a
    case "$(uname -m)" in
        (arm64 | aarch64* | armv8[bl]) { is_arm64() { true; }; };;
        (*) { is_arm64() { false; }; };;
    esac 
    set +a

    is_arm64
}

is_amd64() {
    set -a
    case "$(uname -m)" in
        (amd64 | x*"64") { is_amd64() { true; }; };;
        (*) { is_amd64() { false; }; };;
    esac
    set +a

    is_amd64
}


is_sed_inplace_spaced() { 
    set -a
    case "$(2>&1 sed --help ||:)" in 
        (*'-i[SUFFIX]'*) { is_sed_inplace_spaced() { return 1; }; };;
        (*) { is_sed_inplace_spaced() { return 0; }; };;
    esac
    set +a

    is_sed_inplace_spaced
}

sed_bak() {
    if is_sed_inplace_spaced; then
        set -- -i "$@"
    else
        in_place="-i$(quote "${1-}")"; shift
        set -- "$in_place" "$@"
        unset in_place
    fi
   
    command sed "$@"
}

sed_nobak() {
    sed_bak '' "$@"
}

## macOS id command ##
#     -P      Display the id as a password file entry.
# EXAMPLES
# Show information for the user ‘bob’ as a password file entry:
# id -P bob
# bob:*:0:0::0:0:Robert:/bob:/usr/local/bin/bash

# Ubuntu getent command
# ubuntu@ip-172-31-22-234:~$ getent passwd salmatron
# salmatron:x:17007:17007::/home/salmatron:/bin/bash

getent_passwd_user() (
  set -a
  orex() { "$@" || exit "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "$*")"; }
  set +a

  set +e -f -u

  user=$(orex get_user "${1-}") || exit

  if [ "$(uname -s)" = Darwin ]; then
    orex id -P "${user:?}"; exit
  fi

  orex getent passwd "${user:?}"
)

getent_passwd_user_field() (
  set -a
  orex() { "$@" || exit "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "$*")"; }
  set +a

  set +e -f -u

  user=$(orex get_user "${1-}") || exit

  field="${2:-0}"; field="$(printf '%d' "${field:?}")" || exit
  entry="$(orex getent_passwd_user "${user:?}")" || exit

  export IFS=":"; set -f; set -- ${entry:?};
  shift "${field:?}"; field_value="${1-}"

  ${field_value:+false} || printf '%s\n' "${field_value?}"
)

getent_home_user() { oret getent_passwd_user_field "${1-}" '8'; }

getent_user_shell() { oret getent_passwd_user_field "${1-}" '9'; }

is_local_owner() {
  # $1 = file/dir/link
  ( file="${1-}"; file="${file:?}"; ) || return
  ${LOCAL__USER:+:} samkz__local_user_export
  is_user_owner "${LOCAL__USER:?}" "${1:?}" || return
}

is_user_owner() (
  # $1 = user
  # $2 = file/dir/link
  owner_user="${1-}"; owner_user="$(id -urn "${owner_user:?}")"
  file="${2-}"; file="${file:?}"

  [ -n "$(2>/dev/null find "${2:?}" -maxdepth 0 -user "${1:?}" -print -quit ||:)" ] || return
)

is_group_owner() {
  # $1 = group
  # $2 = file/dir/link
  ( owner_group="${1-}"; file="${2-}"; owner_group="${owner_group:?}"; file="${file:?}"; ) || return
  [ -n "$(2>/dev/null find "${2:?}" -maxdepth 0 -group "${1:?}" -print -quit ||:)" ] || return
}

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
  export -p | orex sed -E -n "s/^export ($(IFS='|'; printf %s "$*"))/\1/p"
)

samkz__print_env_prefixed_grep() (
  [ $# -gt 0 ] || return
  { builtin shopt -so posix ||:; }>/dev/null 2>&1
  prefix="$(printf '%s\|' "$@")"
  export -p | orex grep "^export \(${prefix%'\|'}\)"
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

  orex samkz__print_env_prefixed "${prefix:?}" | orex sort -uo "${env_file:?}"
  orex samkz__chown "${env_file:?}"

  if [ "$program" = "user" ]; then
    admin_env_file="${env_file%/*}/admin.env"

    orex cp -a "${env_file:?}" "${admin_env_file:?}"
    orex sed -i.bak -e 's/^LOCAL__/ADMIN__/g' -- "${admin_env_file:?}" && rm -f -- "${admin_env_file:?}.bak"
  fi
)
#
#str_quote_x() (
#  str="$(printf '%s\n' "${1}EOF" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/")"
#  printf '%s\n' "${str%EOF'}'"
#}

trim_string() {
    # Usage: trim_string "   example   string    "

    # Remove all leading white-space.
    # '${1%%[![:space:]]*}': Strip everything but leading white-space.
    # '${1#${XXX}}': Remove the white-space from the start of the string.
    trim=${1#${1%%[![:space:]]*}}

    # Remove all trailing white-space.
    # '${trim##*[![:space:]]}': Strip everything but trailing white-space.
    # '${trim%${XXX}}': Remove the white-space from the end of the string.
    trim=${trim%${trim##*[![:space:]]}}

    printf '%s\n' "$trim"
}

str_trim() {
    ${1:+:} return 0

    s="$(set -f; printf '%s' $1)"

    if [ ${#s} -lt 3 ]; then 
        printf '%s' "$s"; return
    fi

    # First char after leading whitespace (if any)
    a="${s%"${s#?}"}"
    # Last char before trailing whitespace (if any)
    z="${s#"${s%?}"}"

    # Leading whitespace (if any)
    pre="${1%%"$a"*}"
    # Trailing whitespace (if any)
    post="${1##*"$z"}"

    out="$1"
    out="${out#"$pre"}"
    out="${out%"$post"}"

    printf %s "$out"
}


samkz__pattern_truthy() {
  set -f -- '[Tt]' '[Tt][Rr][Uu][Ee]' '[Yy]' '[Yy][Ee][Ss]' '[Jj]' '[Jj][Aa]'
  printf %s '1 '; printf ' | %s ' "$@"
}

is_truthy() {
  ${1:+:} return 1

  case "$(set -f -- $1; printf %s "$1")" in ( $(samkz__pattern_truthy) ) { return 0; };; esac

  return 1
}

first_word() ( set -f -- $1; printf %s "$1"; )

# Empty output on false, 1 on true
to_true_one() {
  ${1:+:} return 0

  case "$(set -f -- $1; printf %s "$1")" in ( $(samkz__pattern_truthy) );;
   (*) { return 0; };;
  esac

  printf %s 1
}

is_in_PATH() {
   ${1:+:} return 1
   case ":$PATH:" in (*:"${1:?}":*);; (*) { return 1; };; esac
   return 0
}

samkz__lib_config_env_nullify() {
  export SAMKZ__CLEAN_ALL=
  export SAMKZ__CLEAN_USER=
  export SAMKZ__CLEAN_ADMIN=
  export SAMKZ__CLEAN_NGINX=
  export SAMKZ__CLEAN_CADDY=
  export SAMKZ__CLEAN_LETSENCRYPT=
}

samkz__lib_config_env_normalize() {
   ${SAMKZ__CLEAN_ALL+false} || { SAMKZ__CLEAN_ALL="$(to_true_one "${SAMKZ__CLEAN_ALL-}")"; export SAMKZ__CLEAN_ALL; }
   ${SAMKZ__CLEAN_USER+false} || { SAMKZ__CLEAN_USER="$(to_true_one "${SAMKZ__CLEAN_USER-}")"; export SAMKZ__CLEAN_USER; }
   ${SAMKZ__CLEAN_ADMIN+false} || { SAMKZ__CLEAN_ADMIN="$(to_true_one "${SAMKZ__CLEAN_ADMIN-}")"; export SAMKZ__CLEAN_ADMIN; }
   ${SAMKZ__CLEAN_NGINX+false} || { SAMKZ__CLEAN_NGINX="$(to_true_one "${SAMKZ__CLEAN_NGINX-}")"; export SAMKZ__CLEAN_NGINX; }
   ${SAMKZ__CLEAN_CADDY+false} || { SAMKZ__CLEAN_CADDY="$(to_true_one "${SAMKZ__CLEAN_CADDY-}")"; export SAMKZ__CLEAN_CADDY; }
   ${SAMKZ__CLEAN_LETSENCRYPT+false} || { SAMKZ__CLEAN_LETSENCRYPT="$(to_true_one "${SAMKZ__CLEAN_LETSENCRYPT-}")"; export SAMKZ__CLEAN_LETSENCRYPT; }
}


samkz__is_clean_all() { is_truthy "${SAMKZ__CLEAN_ALL-}"; }

samkz__import_env() {
  # $1 = program
  # $2 = generated env: /some/path/$program.env

  set -- "$1" "${LOCAL__ETC:-"$(samkz__local_user_export && printf '%s\n' "${LOCAL__ETC:?}")"}/${1:?}.env"

  samkz__is_clean_all && rm -f "$2"

  if [ -f "$2" ]; then
    samkz__create_env_file "$1"
  fi

  orex [ -f "$2" ]

  set -a; orex . "$2"; set +a
}

samkz__local_user() (
    set +e -u

    set -- "${USER-}" "${SUDO_USER-}" "$(id -urn)" "$(id -un)" "$(logname)" "$(who am i | cut -w -f 1 -)"

    set +u
    while [ -z "${1##root}" ] && 2>/dev/null shift; do :; done
    [ -n "${1##root}" ] && id -urn "${1:?}" && exit

    set -- "${BASH_SOURCE-}" "${0-}" "${HOME-}" "$PWD"

    for f; do u="$(file_user "$f")" && [ -n "${u##root}" ] && id -urn "${u:?}" && exit; done

    exit "1$(>&2 printf '%s\n' "Unable to find non-root user")"
)

samkz__local_user_export() {
    set -a
    LOCAL__USER="$(id -urn)"
    [ -n "${LOCAL__USER##root}" ] || LOCAL__USER="$(samkz__local_user)"
    LOCAL__GROUP="$(id -grn "${LOCAL__USER:?}")"
    LOCAL__UID="$(id -ur "${LOCAL__USER:?}")"
    LOCAL__EUID="$(id -u "${LOCAL__USER:?}")"
    LOCAL__GID="$(id -gr "${LOCAL__USER:?}")"
    LOCAL__EGID="$(id -g "${LOCAL__USER:?}")"
    LOCAL__HOME="$(getent_home_user "${LOCAL__USER:?}")"
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

    case ":$PATH:" in (*:"${LOCAL__BIN:?}":*);; (*) { PATH="${LOCAL__BIN:?}${PATH:+:$PATH}"; };; esac
}


 set +a
