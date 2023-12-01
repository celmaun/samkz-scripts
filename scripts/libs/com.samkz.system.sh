#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2046

{ [ -n "${-##*i*}" ] && type com_samkz_system_sh && return; } >/dev/null 2>&1

set -a

com_samkz_system_sh() {
    set -a

    orex() { "$@" || exit "$?$(>&2 printf   'ERROR[%d]: %s\n' "$?" "$*")"; }
    oret() { "$@" || return "$?$(>&2 printf 'ERROR[%d]: %s\n' "$?" "$*")"; }
    quote() { printf '%s\n' "$1" | orex sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/" ; }

# ubuntu@ip-172-31-22-234:~$ sudo apt instal rsync
# E: Invalid operation instal
# ubuntu@ip-172-31-22-234:~$ sudo apt install rsync
# Reading package lists... Done
# Building dependency tree... Done
# Reading state information... Done
# rsync is already the newest version (3.2.7-0ubuntu0.22.04.2).
# rsync set to manually installed.
# 0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.


install_rsync_debian() (
    orex [ $(id -ur) -eq 0 ]

    export LC_ALL="C"; export DEBIAN_FRONTEND="noninteractive"

    orex apt-get update
    orex apt-get install rsync

    # ubuntu@host:~$ sudo systemctl enable --now rsync
    # Synchronizing state of rsync.service with SysV service script with /lib/systemd/systemd-sysv-install.
    # Executing: /lib/systemd/systemd-sysv-install enable rsync
    systemctl enable --now rsync



#
#
#    ubuntu@ip-172-31-22-234:~$ sudo systemctl status rsync
#    ○ rsync.service - fast remote file copy program daemon
#         Loaded: loaded (/lib/systemd/system/rsync.service; enabled; vendor preset: enabled)
#         Active: inactive (dead)
#      Condition: start condition failed at Thu 2023-11-23 17:05:29 UTC; 5s ago
#                 └─ ConditionPathExists=/etc/rsyncd.conf was not met
#           Docs: man:rsync(1)
#                 man:rsyncd.conf(5)
#
#    Nov 23 11:47:00 ip-172-31-22-234 systemd[1]: Condition check resulted in fast remote file copy program daemon being skipped.
#    Nov 23 14:35:11 ip-172-31-22-234 systemd[1]: Condition check resulted in fast remote file copy program daemon being skipped.
#    Nov 23 17:05:29 ip-172-31-22-234 systemd[1]: Condition check resulted in fast remote file copy program daemon being skipped.



)

install_rsync() (

    if  [ "$(uname -s)" = "Darwin" ]; then
        orex brew install rsync
    else
        orex install_rsync_debian
    fi


    :;
)


samkz__pkg_ensure_installed() (
    # $1 =


    command -V rsync
)

    set +a


}

set +a
