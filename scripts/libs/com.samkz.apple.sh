#!/usr/bin/env bash
# vim:set ft=bash ts=4 sw=4 et :
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2046

{ [ -n "${-##*i*}" ] && type com_samkz_apple_sh && return; } >/dev/null 2>&1

set -a

com_samkz_apple_sh() { :; }

cat /Library/LaunchDaemons/homebrew.mxcl.caddy.plist

cat <<'EOD' >/dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>KeepAlive</key>
	<true/>
	<key>Label</key>
	<string>homebrew.mxcl.caddy</string>
	<key>LimitLoadToSessionType</key>
	<array>
		<string>Aqua</string>
		<string>Background</string>
		<string>LoginWindow</string>
		<string>StandardIO</string>
		<string>System</string>
	</array>
	<key>ProgramArguments</key>
	<array>
		<string>/opt/homebrew/opt/caddy/bin/caddy</string>
		<string>run</string>
		<string>--config</string>
		<string>/opt/homebrew/etc/Caddyfile</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardErrorPath</key>
	<string>/opt/homebrew/var/log/caddy.log</string>
	<key>StandardOutPath</key>
	<string>/opt/homebrew/var/log/caddy.log</string>
</dict>
</plist>
EOD

# salmatron@abdbke go % cat ~/Library/LaunchAgents/homebrew.mxcl.caddy.plist
cat <<'XML' >/dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>KeepAlive</key>
	<true/>
	<key>Label</key>
	<string>homebrew.mxcl.caddy</string>
	<key>LimitLoadToSessionType</key>
	<array>
		<string>Aqua</string>
		<string>Background</string>
		<string>LoginWindow</string>
		<string>StandardIO</string>
		<string>System</string>
	</array>
	<key>ProgramArguments</key>
	<array>
		<string>/opt/homebrew/opt/caddy/bin/caddy</string>
		<string>run</string>
		<string>--config</string>
		<string>/opt/homebrew/etc/Caddyfile</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardErrorPath</key>
	<string>/opt/homebrew/var/log/caddy.log</string>
	<key>StandardOutPath</key>
	<string>/opt/homebrew/var/log/caddy.log</string>
</dict>
</plist>
XML

 set +a
