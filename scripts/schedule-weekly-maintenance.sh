#!/bin/bash
# Schedule the weekly unattended maintenance run as a user LaunchAgent.
#
# Renders launchd/local.macos-hardening.weekly-maintenance.plist.template into
# ~/Library/LaunchAgents/ and (re)loads it. Idempotent: safe to re-run after
# editing the template. `--remove` unloads and deletes the agent.
#

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LABEL="local.macos-hardening.weekly-maintenance"
TEMPLATE="$SCRIPT_DIR/../launchd/$LABEL.plist.template"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

# The weekly scan uses Cisco's ClamAV package (Cisco-Talos/clamav#1887, PR #1873);
# revert CLAMAV_BIN to /opt/homebrew/bin once Homebrew ships a fixed clamav.
CLAMAV_BIN="/usr/local/clamav/bin"

unload() {
    # bootout fails harmlessly when the job isn't loaded
    launchctl bootout "$DOMAIN" "$TARGET" 2>/dev/null || true
}

if [ "${1:-}" = "--remove" ]; then
    echo "=== Removing $LABEL ==="
    unload
    rm -f "$TARGET"
    echo "✓ Agent unloaded and removed"
    exit 0
fi

echo "=== Scheduling weekly unattended maintenance ==="
echo

if [ ! -f "$TEMPLATE" ]; then
    echo "❌ Template not found: $TEMPLATE"
    exit 1
fi

if [ ! -r "$HOME/.config/macos-security-hardening/notify.conf" ]; then echo "⚠️  no ~/.config/macos-security-hardening/notify.conf — runs will log but not notify (see scripts/notify.conf.example)"; fi
if [ ! -x "$CLAMAV_BIN/freshclam" ]; then
    echo "❌ $CLAMAV_BIN/freshclam not found — install Cisco's ClamAV .pkg first (see README)"
    exit 1
fi

# StandardOutPath/StandardErrorPath target this directory; launchd will not
# create it and silently drops output if it is missing.
mkdir -p "$HOME/logs/weekly-maintenance" "$HOME/Library/LaunchAgents"

# Render: the only substitution is the home directory, because launchd does
# not expand ~ or $HOME in path keys.
sed "s|__HOME__|$HOME|g" "$TEMPLATE" > "$TARGET"
plutil -lint "$TARGET" > /dev/null

# Reload so template edits take effect
unload
launchctl bootstrap "$DOMAIN" "$TARGET"

echo "✓ $TARGET"
echo "✓ Loaded into $DOMAIN — Sundays 10:00"
if [ "${1:-}" = "--now" ]; then echo "→ kickstarting one run now"; launchctl kickstart -k "$DOMAIN/$LABEL"; fi
echo
echo "Status:  launchctl print $DOMAIN/$LABEL | grep -E 'state|last exit'"
echo "Logs:    ~/logs/weekly-maintenance/YYYY-MM-DD.log"
echo "Remove:  $(basename "$0") --remove"
echo
