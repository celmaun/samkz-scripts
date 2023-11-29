#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2043

{ type com_samkz_web_servers_sh && return; } >/dev/null 2>&1

set -a

com_samkz_web_servers_sh() { :; }

orex() { "$@" || exit "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "$*")"; }
oret() { "$@" || return "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "$*")"; }

if (>/dev/null 2>&1 type com_samkz_utils_sh); then :; else
  SAMKZ__UTILS_LIB_SH="${SAMKZ__UTILS_LIB_SH:-"$(
    f="${BASH_SOURCE:?}" && [ -f "$f" ] && f="$(readlink -f -- "$f")" && d="${f%/*}";
    for f in "$d"/com.samkz.utils*.sh; do :; done; [ -f "$f" ] && readlink -f -- "$f";
  )"}"

  orex . "${SAMKZ__UTILS_LIB_SH:?}"
fi


quote() { printf '%s\n' "$1" | orex sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/" ; }

canon_file() { [ -n "$1" ] && [ -f "$1" ] && readlink -f -- "$1"; }
canon_dir() { [ -n "$1" ] && [ -d "$1" ] && readlink -f -- "$1"; }
canon_exe() { [ -n "$1" ] && [ -f "$1" ] && [ -x "$1" ] && readlink -f -- "$1"; }

is_binary() { [ -f "${1-}" ] || return; case "$(orex file "${1:?}")" in (*executable*) return 0;; esac; return 1; }
is_shell_script() { [ -f "${1-}" ] || return; case "$(orex file "${1:?}")" in (*shell*script*) return 0;; esac; return 1; }
is_shell_program() { [ -f "${1-}" ] && [ -x "$1" ] || return; case "$(orex file "${1:?}")" in (*shell*script*) return 0;; esac; return 1; }

get_super_group() { if [ "$(uname -s)" = Darwin ]; then printf '%s\n' 'staff'; else printf '%s\n' 'sudo'; fi; }

samkz__homebrew__install() {
  [ "$(uname -s)" = "Darwin" ] || return 0

  if [ -x "$(2>/dev/null command -v brew || printf '%s\n' '/opt/homebrew/bin/brew')" ]; then :; else
    >&2 printf '%s\n' 'Installing Homebrew...'
    >&2 printf '%s\n' '... The Missing Package Manager for macOS!'
    orex /bin/bash -xc "$(orex curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")"
  fi

  orex samkz__homebrew__export
}

samkz__homebrew__export() {
  set -- "$(2>/dev/null command -v brew || printf '%s\n' '/opt/homebrew/bin/brew')"
  orex [ -x "$1" ]

  >&2 printf '%s\n' 'Loading  Homebrew shell environment...'
  eval "$("$1" shellenv sh)"
}

samkz__nginx__install() {
    orex [ "$(id -urn)" = "root" ]

    if [ "$(uname -s)" = "Linux" ]; then
       orex samkz__require_ubuntu

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

    elif [ "$(uname -s)" = "Darwin" ]; then
      orex samkz__homebrew__install

      >&2 printf '%s\n' 'Installing Nginx...'
      orex brew install nginx
    else
      exit "1$(>&2 printf '%s\n' "Windows is not supported. Please try macOS or Ubuntu Linux.")"
    fi

    orex samkz__nginx__setup

}

samkz__nginx__setup() {
    >&2 printf '%s\n' 'Setting up Nginx...'

    orex samkz__nginx__export

    orex [ -d "${MAIN__NGINX__ETC:?}" ]
    orex [ -d "${MAIN__NGINX__SITES:?}" ]

    if [ "$(id -urn)" = "root" ]; then
        orex chgrp -R "$(get_super_group)" \
            "${MAIN__NGINX__ETC:?}" \
            "${MAIN__NGINX__SITES:?}"

        orex chmod -R g+rwX \
            "${MAIN__NGINX__ETC:?}" \
            "${MAIN__NGINX__SITES:?}"
    fi

}


samkz__nginx__export() {
    set +e -u

    for _ in _; do
        set -a
        MAIN__NGINX__EXE="$(orex command -v nginx)" || break
        MAIN__NGINX__PRG="$(orex canon_exe "${MAIN__NGINX__EXE:?}")" || break
        MAIN__NGINX__ETC_CONFIG="$(orex canon_file "$("${MAIN__NGINX__PRG:?}" -t 2>&1 | orex sed -n 's@^.* configuration *file *\(/.*\.conf\) test .*$@\1@p')")" || break
        MAIN__NGINX__ETC="${MAIN__NGINX__ETC_CONFIG%/*}"; [ -d "$MAIN__NGINX__ETC" ] || break
        MAIN__NGINX__SITES="$(orex sed -n 's@^[\t ]*include *\(.*\)/\*\;.*$@\1@p' < "${MAIN__NGINX__ETC_CONFIG:?}")"
        [ -n "${MAIN__NGINX__SITES##/*}" ] && MAIN__NGINX__SITES="${MAIN__NGINX__ETC:?}/${MAIN__NGINX__SITES:?}"
        MAIN__NGINX__SITES="$(orex canon_dir "${MAIN__NGINX__SITES:?}")" || break
        set +a
        return 0
    done
    set +a
    unset MAIN__NGINX__EXE MAIN__NGINX__PRG MAIN__NGINX__ETC_CONFIG MAIN__NGINX__ETC MAIN__NGINX__SITES
    return 1
}


samkz__require_ubuntu() {
  for _ in _; do
    [ "$(uname -s)" = "Linux" ] || break
     case "$(uname -a)" in (*Ubuntu*) { return 0; };; esac
  done

  exit "1$(>&2 printf '%s\n' "Please install Ubuntu, it's pretty nice.")"
}

samkz__nginx__service() {
  orex [ "$(id -urn)" = "root" ]

  subcommand="$1"; : "${subcommand:?}"

  case "$subcommand" in (stop|start|restart);;
    (*) { exit "1$(>&2 printf '%s\n' "samkz__nginx__service: Invalid subcommand '$subcommand'. Accepted: stop, start, restart")"; };;
  esac

  if [ "$(uname -s)" = "Linux" ]; then
    orex samkz__require_ubuntu
    >&2 printf '%s\n' "Nginx service to $subcommand..."
    orex systemctl "$subcommand" nginx
  elif [ "$(uname -s)" = "Darwin" ]; then
    orex samkz__homebrew__export
    >&2 printf '%s\n' "Nginx service to $subcommand..."
    orex brew services "$subcommand" nginx
  else
    exit "1$(>&2 printf '%s\n' "Windows is not supported. Please try macOS or Ubuntu Linux.")"
  fi
}


samkz__caddy__install() {
    orex [ "$(id -urn)" = "root" ]

    if [ "$(uname -s)" = "Linux" ]; then
        orex samkz__require_ubuntu

        >&2 printf '%s\n' 'Updating package manager caches...'

        orex apt-get update

        # https://caddyserver.com/docs/install#debian-ubuntu-raspbian
        # Debian, Ubuntu, Raspbian
        # Installing this package automatically starts and runs Caddy as a systemd service named caddy. It also comes with an optional caddy-api service which is not enabled by default, but should be used if you primarily configure Caddy via its API instead of config files.
        #
        # After installing, please read the service usage instructions.
        #
        # Stable releases:
        >&2 printf '%s\n' 'Installing common dependencies...'
       # Common dependencies for various packages
        orex apt install -y debian-keyring debian-archive-keyring apt-transport-https \
            ca-certificates curl gnupg lsb-release

        >&2 printf '%s\n' 'Adding APT GPG key for Caddy...'
        orex curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | orex gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

        >&2 printf '%s\n' 'Adding APT repo for Caddy...'
        orex curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | orex tee /etc/apt/sources.list.d/caddy-stable.list

        orex apt update

        >&2 printf '%s\n' 'Installing Caddy...'
        orex apt install -y caddy

    elif [ "$(uname -s)" = "Darwin" ]; then
        orex samkz__homebrew__install

        >&2 printf '%s\n' 'Installing Caddy...'
        orex brew install caddy
    else
        exit "1$(>&2 printf '%s\n' "Windows is not supported. Please try macOS or  Ubuntu Linux.")"
    fi

    orex samkz__caddy__setup

}


samkz__caddy__setup() {
  ${LOCAL__HOME:+:} orex samkz__local_user_export

  set -a
  # @TODO
  MAIN__CADDY__HOME="${LOCAL__HOME:?}/caddy"
  MAIN__CADDY__CMD="${MAIN__CADDY__HOME:?}/caddy"
  MAIN__CADDY__LOGS="${MAIN__CADDY__HOME:?}/logs"
  MAIN__CADDY__STORAGE="${MAIN__CADDY__HOME:?}/storage"
  MAIN__CADDY__SITES="${MAIN__CADDY__HOME:?}/sites-enabled"
  MAIN__CADDY__SITES_ALL="${MAIN__CADDY__HOME:?}/sites-available"
  set +a
}

samkz__letsencrypt__install() {
    orex [ "$(id -urn)" = "root" ]

    if [ "$(uname -s)" = "Linux" ]; then

      orex samkz__require_ubuntu

      >&2 printf '%s\n' 'Updating package manager caches...'

      orex apt-get update

      >&2 printf '%s\n' 'Installing Python 3...'
      # Python3 (used by e.g., certbot)
      orex apt-get -y install python3 python3-pip

      >&2 printf '%s\n' 'Installing libsecret-tools...'
      orex apt-get -y install libsecret-tools

    elif [ "$(uname -s)" = "Darwin" ]; then

      orex samkz__homebrew__install

      >&2 printf '%s\n' 'Installing Python 3...'
      orex brew install python3

    else

      exit "1$(>&2 printf '%s\n' "Windows is not supported. Please try macOS or Ubuntu Linux.")"

    fi


    # https://pip.pypa.io/en/stable/installation/
    # ensurepip
    # Python comes with an ensurepip module1, which can install pip in a Python environment.

    #python3 -m ensurepip --upgrade ||:

    # Ensure pip, setuptools, and wheel are up to date
    # While pip alone is sufficient to install from pre-built binary archives, up to date copies of the setuptools and wheel projects are
    # useful to ensure you can also install from source archives:
    >&2 printf '%s\n' 'Installing pip package management stuff...'

    oret python3 -m pip install -U pip setuptools wheel ||:
    orex pip3 install -U pip
    orex pip3 install -U pyopenssl

    ## SSL
    # https://certbot-dns-cloudflare.readthedocs.io/en/stable/
    # Credentials
    # Use of this plugin requires a configuration file containing Cloudflare API credentials, obtained from your Cloudflare dashboard.
    # Previously, Cloudflare’s “Global API Key” was used for authentication, however this key can access the entire Cloudflare API for all domains in your account, meaning it could cause a lot of damage if leaked.
    # Cloudflare’s newer API Tokens can be restricted to specific domains and operations, and are therefore now the recommended authentication option.
    # The Token needed by Certbot requires Zone:DNS:Edit permissions for only the zones you need certificates for.
    # Using Cloudflare Tokens also requires at least version 2.3.1 of the cloudflare python module. If the version that automatically installed with this plugin is older than that, and you can’t upgrade it on your system, you’ll have to stick to the Global key.

    >&2 printf '%s\n' 'Installing Python modules, Certbot and Cloudflare...'
    orex pip3 install -U cloudflare certbot-dns-cloudflare

    orex samkz__letsencrypt__setup
}

samkz__letsencrypt__setup() {

    orex samkz__letsencrypt__export

    orex [ -d "${MAIN__LETSENCRYPT__CONFIG_DIR:?}" ]
    orex [ -d "${MAIN__LETSENCRYPT__RENEWAL_DIR:?}" ]
    orex [ -d "${MAIN__LETSENCRYPT__LIVE_DIR:?}" ]
    orex [ -d "${MAIN__LETSENCRYPT__WORK_DIR:?}" ]
    orex [ -d "${MAIN__LETSENCRYPT__LOGS_DIR:?}" ]

    if [ "$(id -urn)" = "root" ]; then
        orex chgrp -R "$(get_super_group)" \
            "${MAIN__LETSENCRYPT__CONFIG_DIR:?}" \
            "${MAIN__LETSENCRYPT__RENEWAL_DIR:?}" \
            "${MAIN__LETSENCRYPT__LIVE_DIR:?}" \
            "${MAIN__LETSENCRYPT__WORK_DIR:?}" \
            "${MAIN__LETSENCRYPT__LOGS_DIR:?}"

        orex chmod -R g+rwX \
            "${MAIN__LETSENCRYPT__CONFIG_DIR:?}" \
            "${MAIN__LETSENCRYPT__RENEWAL_DIR:?}" \
            "${MAIN__LETSENCRYPT__LIVE_DIR:?}" \
            "${MAIN__LETSENCRYPT__WORK_DIR:?}" \
            "${MAIN__LETSENCRYPT__LOGS_DIR:?}"
    fi


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

samkz__letsencrypt__export() {
  ${LOCAL__ETC:+:} orex samkz__local_user_export

  #   -c CONFIG_FILE, --config CONFIG_FILE
  #                     path to config file (default: /etc/letsencrypt/cli.ini
  #                     and ~/.config/letsencrypt/cli.ini)
  # # --config-dir CONFIG_DIR Configuration directory. (default: /etc/letsencrypt)
    # --work-dir WORK_DIR   Working directory. (default: /var/lib/letsencrypt)
    # --logs-dir LOGS_DIR   Logs directory. (default: /var/log/letsencrypt)
    set -a
    MAIN__LETSENCRYPT__CONFIG_DIR="/etc/letsencrypt"
    MAIN__LETSENCRYPT__RENEWAL_DIR="/etc/letsencrypt/renewal"
    MAIN__LETSENCRYPT__CONFIG_CLI="${MAIN__LETSENCRYPT__CONFIG_DIR:?}/cli.ini"
    ${LOCAL__ETC:+false} || MAIN__LETSENCRYPT__USER_CONFIG_CLI="${LOCAL__ETC:?}/letsencrypt/cli.ini"
    MAIN__LETSENCRYPT__LIVE_DIR="/etc/letsencrypt/live"
    MAIN__LETSENCRYPT__WORK_DIR="/var/lib/letsencrypt"
    MAIN__LETSENCRYPT__LOGS_DIR="/var/log/letsencrypt"
    set +a
}

set +a  