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
    # Time-limited, and a failure is reported but never stops the run: on
    # 2026-11-01 a failed refresh ended the run before the ClamAV scan.
    # "FAILED" is a word weekly-maintenance-run.sh alerts on.
    TMO=$(command -v gtimeout || command -v timeout || true)
    UPD_OUT=$(${TMO:+$TMO 300} brew update --quiet 2>&1); UPD_RC=$?
    printf '%s\n' "$UPD_OUT" | tail -3
    [ $UPD_RC -ne 0 ] && echo "   ⚠️  Homebrew refresh FAILED (exit $UPD_RC); the outdated list may be stale"
    OUTDATED=$(${TMO:+$TMO 120} brew outdated 2>/dev/null) \
        || echo "   ⚠️  brew outdated FAILED or timed out"   # no --greedy: auto_updates casks (iTerm2, Obsidian…) update themselves
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

# 3. ClamAV update & scan: the full scan on the month's first run (day 1-7,
#    unattended only; Martin, 2026-11-12), the quick scan otherwise.
echo
echo "🔍 Running malware scan..."
if [ $UNATTENDED -eq 1 ] && [ "$(date +%d)" -le 7 ]; then
    "$SCRIPT_DIR/clamscan-quick.sh" --full
else
    "$SCRIPT_DIR/clamscan-quick.sh"
fi

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
