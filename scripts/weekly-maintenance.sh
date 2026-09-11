#!/bin/bash
# Weekly Mac Maintenance
#
# Orchestrator only. Homebrew CLEANUP lives in mac-cleanup.sh and is not
# repeated here — this script only does update/upgrade, which cleanup cannot.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=== Weekly Mac Maintenance ==="
echo "Started: $(date)"
echo

# 1. System cleanup (includes Homebrew cleanup/autoremove)
echo "🧹 Running cleanup..."
"$SCRIPT_DIR/mac-cleanup.sh"

# 2. Homebrew update/upgrade (cleanup already handled above)
echo
echo "🍺 Updating Homebrew..."
brew update && brew upgrade

# 3. ClamAV update & scan
echo
echo "🔍 Running malware scan..."
"$SCRIPT_DIR/clamscan-quick.sh"

# 4. Check for macOS updates
echo
echo "🍎 Checking for macOS updates..."
softwareupdate -l

echo
echo "=========================================="
echo "  ✅ Weekly Maintenance Complete"
echo "=========================================="
echo "Finished: $(date)"
echo
