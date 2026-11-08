#!/bin/bash
# Schedule ClamAV definition updates via a user LaunchAgent.
#
# Renders launchd/local.clamav.freshclam.plist.template into
# ~/Library/LaunchAgents/ and (re)loads it. Idempotent: safe to re-run after
# editing the template. `--remove` unloads and deletes the agent.
#
# Background: definitions sat at a 7 April build until 16 September 2026 because
# every freshclam call in this repo was behind a manual alias. A scanner with
# five-month-old signatures looks like coverage and isn't.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LABEL="local.clamav.freshclam"
TEMPLATE="$SCRIPT_DIR/../launchd/$LABEL.plist.template"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

# Cisco's package, not Homebrew (Cisco-Talos/clamav#1887, PR #1873); revert
# CLAMAV_BIN to /opt/homebrew/bin once Homebrew ships a fixed clamav.
CLAMAV_BIN="/usr/local/clamav/bin"
CLAMAV_LOG="/opt/homebrew/var/log/clamav/freshclam.log"

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

echo "=== Scheduling ClamAV definition updates ==="
echo

if [ ! -f "$TEMPLATE" ]; then
    echo "❌ Template not found: $TEMPLATE"
    exit 1
fi

if [ ! -x "$CLAMAV_BIN/freshclam" ]; then
    echo "❌ $CLAMAV_BIN/freshclam not found — install Cisco's ClamAV .pkg first (see README)"
    exit 1
fi

# StandardOutPath/StandardErrorPath target this directory; launchd will not
# create it and silently drops output if it is missing.
mkdir -p "$HOME/logs" "$HOME/Library/LaunchAgents"

# Render: the only substitution is the home directory, because launchd does
# not expand ~ or $HOME in path keys.
sed "s|__HOME__|$HOME|g" "$TEMPLATE" > "$TARGET"
plutil -lint "$TARGET" > /dev/null

# Reload so template edits take effect
unload
launchctl bootstrap "$DOMAIN" "$TARGET"

echo "✓ $TARGET"
echo "✓ Loaded into $DOMAIN — daily at 12:00 and at login"
echo
echo "Status:  launchctl print $DOMAIN/$LABEL | grep -E 'state|last exit'"
echo "Log:     $CLAMAV_LOG"
echo "Remove:  $(basename "$0") --remove"
echo
