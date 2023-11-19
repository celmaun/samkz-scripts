#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2043

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

get_super_group() { if [ "$(uname -s)" = Darwin ]; then printf '%s\n' 'staff'; else printf '%s\n' 'sudo'; fi; }

install__MAIN__NGINX() {
    orex [ "$(id -urn)" = "root" ]
    orex [ "$(uname -s)" = "Linux" ]
    case "$(uname -a)" in (*Ubuntu*);; (*) exit "1$(>&2 printf '%s\n' "Please install Ubuntu, it's pretty nice.")";; esac
   
    >&2 printf '%s\n' 'Updating package manager caches...'

    orex apt-get update


    >&2 printf '%s\n' 'Installing common dependencies...'
    # Common dependencies for various packages
    orex apt-get -y install \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
   
    >&2 printf '%s\n' 'Updating package manager caches...'

    orex apt-get update

    >&2 printf '%s\n' 'Installing Nginx...'
    # Nginx
    orex apt-get -y install nginx

    orex setup__MAIN__NGINX

}

setup__MAIN__NGINX() {
   >&2 printf '%s\n' 'Setting up Nginx...'

    export__MAIN__NGINX

    orex [ -d "${MAIN__NGINX__ETC:?}" ]
    orex [ -d "${MAIN__NGINX__SITES:?}" ]

    orex chgrp -R "$(get_super_group)" \
        "${MAIN__NGINX__ETC:?}" \
        "${MAIN__NGINX__SITES:?}"
    
    orex chmod -R g+rwX \
        "${MAIN__NGINX__ETC:?}" \
        "${MAIN__NGINX__SITES:?}"
}


export__MAIN__NGINX() {
    set +e -u

    for _ in _; do
        set -a
        MAIN__NGINX__EXE="$(2>/dev/null command -v nginx)" || break
        MAIN__NGINX__PRG="$(canon_exe "${MAIN__NGINX__EXE:?}")" || break
        MAIN__NGINX__ETC_CONFIG="$(canon_file "$("${MAIN__NGINX__PRG:?}" -t 2>&1 | sed -n 's@^.* configuration *file *\(/.*\.conf\) test .*$@\1@p')")" || break
        MAIN__NGINX__ETC="${MAIN__NGINX__ETC_CONFIG%/*}"; [ -d "$MAIN__NGINX__ETC" ] || break
        MAIN__NGINX__SITES="$(sed -n 's@^[\t ]*include *\(.*\)/\*\;.*$@\1@p' < "${MAIN__NGINX__ETC_CONFIG:?}")"
        [ -n "${MAIN__NGINX__SITES##/*}" ] && MAIN__NGINX__SITES="${MAIN__NGINX__ETC:?}/${MAIN__NGINX__SITES:?}"
        MAIN__NGINX__SITES="$(canon_dir "${MAIN__NGINX__SITES:?}")" || break
        set +a
        return 0
    done
    set +a
    unset MAIN__NGINX__EXE MAIN__NGINX__PRG MAIN__NGINX__ETC_CONFIG MAIN__NGINX__ETC MAIN__NGINX__SITES
    return 1
}



install__MAIN__LETSENCRYPT() {
    orex [ "$(id -urn)" = "root" ]
    orex [ "$(uname -s)" = "Linux" ]
    case "$(uname -a)" in (*Ubuntu*);; (*) exit "1$(>&2 printf '%s\n' "Please install Ubuntu, it's pretty nice.")";; esac
   
    >&2 printf '%s\n' 'Updating package manager caches...'

    orex apt-get update


    >&2 printf '%s\n' 'Installing Python 3...'
    # Python3 (used by e.g., certbot)
    orex apt-get -y install python3 python3-pip

    >&2 printf '%s\n' 'Installing libsecret-tools...'
    orex apt-get -y install libsecret-tools

    # https://pip.pypa.io/en/stable/installation/
    # ensurepip
    # Python comes with an ensurepip module1, which can install pip in a Python environment.

    #python3 -m ensurepip --upgrade ||:

    # Ensure pip, setuptools, and wheel are up to date
    # While pip alone is sufficient to install from pre-built binary archives, up to date copies of the setuptools and wheel projects are
    # useful to ensure you can also install from source archives:
    >&2 printf '%s\n' 'Installing pip package management stuff...'
    oret python3 -m pip install -U pip setuptools wheel ||:
    orex pip3 -U install pip
    orex pip3 -U install pyopenssl

    ## SSL
    # https://certbot-dns-cloudflare.readthedocs.io/en/stable/
    # Credentials
    # Use of this plugin requires a configuration file containing Cloudflare API credentials, obtained from your Cloudflare dashboard.
    # Previously, Cloudflare’s “Global API Key” was used for authentication, however this key can access the entire Cloudflare API for all domains in your account, meaning it could cause a lot of damage if leaked.
    # Cloudflare’s newer API Tokens can be restricted to specific domains and operations, and are therefore now the recommended authentication option.
    # The Token needed by Certbot requires Zone:DNS:Edit permissions for only the zones you need certificates for.
    # Using Cloudflare Tokens also requires at least version 2.3.1 of the cloudflare python module. If the version that automatically installed with this plugin is older than that, and you can’t upgrade it on your system, you’ll have to stick to the Global key.

    >&2 printf '%s\n' 'Installing Python modules, Certbot and Cloudflare...'
    orex pip3 install -U cloudflare certbot-nginx certbot-dns-cloudflare

    orex setup__MAIN__LETSENCRYPT
}

setup__MAIN__LETSENCRYPT() {
    orex [ "$(id -urn)" = "root" ]

    orex export__MAIN__LETSENCRYPT

    orex [ -d "${MAIN__LETSENCRYPT__CONFIG_DIR:?}" ]
    orex [ -d "${MAIN__LETSENCRYPT__LIVE_DIR:?}" ]
    orex [ -d "${MAIN__LETSENCRYPT__WORK_DIR:?}" ]
    orex [ -d "${MAIN__LETSENCRYPT__LOGS_DIR:?}" ]

    orex chgrp -R "$(get_super_group)" \
        "${MAIN__LETSENCRYPT__CONFIG_DIR:?}" \
        "${MAIN__LETSENCRYPT__LIVE_DIR:?}" \
        "${MAIN__LETSENCRYPT__WORK_DIR:?}" \
        "${MAIN__LETSENCRYPT__LOGS_DIR:?}"
    
    orex chmod -R g+rwX \
        "${MAIN__LETSENCRYPT__CONFIG_DIR:?}" \
        "${MAIN__LETSENCRYPT__LIVE_DIR:?}" \
        "${MAIN__LETSENCRYPT__WORK_DIR:?}" \
        "${MAIN__LETSENCRYPT__LOGS_DIR:?}"

    #   orex [ -n "${LEWP__CLOUDFLARE_DNS_API_KEY-}" ]
    #   cf_dns_creds_lensify_ai="${LOCAL__HOME:?}/.cf-dns-creds/lensify.ai.ini"
    #   orex mkdir -p "${cf_dns_creds_lensify_ai%/*}"
    #   # (umask 0077; printf 'dns_cloudflare_api_token=%s\n' 'XXXXXXX' > ~/.cf-dns-creds/lensify.ai.ini ;)
    #   (umask 0077; printf 'dns_cloudflare_api_token=%s\n' "${LEWP__CLOUDFLARE_DNS_API_KEY:?}" > "${cf_dns_creds_lensify_ai:?}"; )
    # chown -R "$LOCAL__USER:" "${cf_dns_creds_lensify_ai%/*}"
    #  #orex sudo certbot certonly \
    #   sudo certbot certonly \
    #     --verbose \
    #     --keep-until-expiring \
    #     --agree-tos \
    #     --no-eff-email \
    #     --non-interactive \
    #     --dns-cloudflare \
    #     --dns-cloudflare-credentials "${cf_dns_creds_lensify_ai:?}" \
    #     -d 'lensify.ai' -d '*.lensify.ai'

}

export__MAIN__LETSENCRYPT() {
  #   -c CONFIG_FILE, --config CONFIG_FILE
  #                     path to config file (default: /etc/letsencrypt/cli.ini
  #                     and ~/.config/letsencrypt/cli.ini)
  # # --config-dir CONFIG_DIR Configuration directory. (default: /etc/letsencrypt)
    # --work-dir WORK_DIR   Working directory. (default: /var/lib/letsencrypt)
    # --logs-dir LOGS_DIR   Logs directory. (default: /var/log/letsencrypt)
    set -a
    MAIN__LETSENCRYPT__CONFIG_DIR="/etc/letsencrypt"
    MAIN__LETSENCRYPT__CONFIG_CLI="${MAIN__LETSENCRYPT__CONFIG_DIR:?}/cli.ini"
    ${LOCAL__ETC:+ export MAIN__LETSENCRYPT__USER_CONFIG_CLI="${LOCAL__ETC:?}/letsencrypt/cli.ini" }
    MAIN__LETSENCRYPT__LIVE_DIR="/etc/letsencrypt/live"
    MAIN__LETSENCRYPT__WORK_DIR="/var/lib/letsencrypt"
    MAIN__LETSENCRYPT__LOGS_DIR="/var/log/letsencrypt"
    set +a
}

set +a  