#!/bin/bash
# Weekly Mac Maintenance
#
# Orchestrator only. Homebrew CLEANUP lives in mac-cleanup.sh and is not
# repeated here — this script only does update/upgrade, which cleanup cannot.
#
#   weekly-maintenance.sh               interactive: cleanup → brew upgrade → scan → macOS updates
#   weekly-maintenance.sh --unattended  launchd:     cleanup → brew update + REPORT outdated → scan → macOS updates
#
# Unattended mode never runs `brew upgrade`. A blind upgrade replaces binaries
# under running services (the old process keeps running from a deleted file
# until something restarts it), changes Cellar paths so LuLu prompts for every
# ad-hoc-signed binary, and cask upgrades of running apps and system extensions
# want a person present. The timer's job is to make the list impossible to
# forget; applying it stays a deliberate act at the keyboard.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UNATTENDED=0
[ "${1:-}" = "--unattended" ] && UNATTENDED=1

echo "=== Weekly Mac Maintenance$( [ $UNATTENDED -eq 1 ] && echo ' (unattended)' ) ==="
echo "Started: $(date)"
echo

# 1. System cleanup (includes Homebrew cleanup/autoremove; sudo steps skip
#    themselves honestly when there is no tty)
echo "🧹 Running cleanup..."
"$SCRIPT_DIR/mac-cleanup.sh"

# 2. Homebrew
echo
if [ $UNATTENDED -eq 1 ]; then
    echo "🍺 Refreshing Homebrew metadata (no upgrade in unattended mode)..."
    brew update --quiet 2>&1 | tail -3
    OUTDATED=$(brew outdated --greedy 2>/dev/null)
    if [ -n "$OUTDATED" ]; then
        echo "   Outdated ($(printf '%s\n' "$OUTDATED" | wc -l | tr -d ' ')) — run 'weekly' or 'brew upgrade' at the keyboard:"
        printf '%s\n' "$OUTDATED" | sed 's/^/     /'
    else
        echo "   ✓ Nothing outdated"
    fi
else
    echo "🍺 Updating Homebrew..."
    brew update && brew upgrade
fi

# 3. ClamAV update & scan
echo
echo "🔍 Running malware scan..."
"$SCRIPT_DIR/clamscan-quick.sh"

# 4. Check for macOS updates (list only — never installs)
echo
echo "🍎 Checking for macOS updates..."
softwareupdate -l 2>&1 | grep -vE '^\s*$' | tail -8

echo
echo "=========================================="
echo "  ✅ Weekly Maintenance Complete"
echo "=========================================="
echo "Finished: $(date)"
echo
