#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317


set -a

export_LOCAL__USER() {
    set -a
    LOCAL__USER="$(
      set +e -u

      file_user() { [ -e "$1" ] && x="$(command ls -ld "$1")" && x="${x#* * }" && x="${x%% *}" && [ -n "$x" ] && printf '%s\n' "${x:?}"; }

      set -- "${LOCAL__USER-}" "$(id -urn)" "$(id -un)" "${APPCON__USER__ADMIN-}" "${SUDO_USER-}"
      for u; do [ -n "${u##root}" ] && printf '%s\n' "${u:?}" && exit; done
      set -- "${BASH_SOURCE-}" "${0-}" "$PWD"
      for f; do u="$(file_user "$f")" && [ -n "${u##root}" ] && printf '%s\n' "${u:?}" && exit; done

      exit "1$(>&2 printf '%s\n' "Unable to find non-root user")"
    )"

    LOCAL__GROUP="$(id -grn "${LOCAL__USER:?}")"
    LOCAL__UID="$(id -ur "${LOCAL__USER:?}")"
    LOCAL__EUID="$(id -u "${LOCAL__USER:?}")"
    LOCAL__GID="$(id -gr "${LOCAL__USER:?}")"
    LOCAL__EGID="$(id -g "${LOCAL__USER:?}")"
    eval "LOCAL__HOME=~${LOCAL__USER:?}"
    set +a
  }

  export_USER__BIN() {
    USER__BIN="${USER__BIN:-"$(
      set -- 'bin' '.bin' '.local/bin'
      for d; do d="$HOME/$d"; case ":$PATH:" in (*:"$d":*) { printf %s "$d"; exit; };; esac; done
    )"}"
    USER__BIN="${USER__BIN:-"$HOME/bin"}"; export USER__BIN
    mkdir -p "$USER__BIN" || return "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "mkdir -p $USER__BIN")"
    case ":$PATH:" in *:"${USER__BIN:?}":*);; *) PATH="${USER__BIN:?}${PATH:+:$PATH}";; esac;
  }

  set +a  