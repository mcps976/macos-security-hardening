#!/bin/bash
# macOS Security Audit
#
# Canonical source of the system-security checks. run_full_audit.sh CALLS this
# script rather than repeating these commands — do not duplicate them there.

set -uo pipefail

mkdir -p ~/logs
LYNIS_LOG=~/logs/lynis-$(date +%Y%m%d).log

echo "=== macOS Security Audit ==="
echo

echo "1️⃣  Running Lynis audit..."
echo
yes "" | sudo lynis audit system --quick --no-colors 2>/dev/null | tee "$LYNIS_LOG"

echo
echo "2️⃣  Checking security settings..."
echo

echo "FileVault:"
fdesetup status

echo
echo "SIP (System Integrity Protection):"
csrutil status

echo
echo "Firewall:"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

echo
echo "Gatekeeper:"
spctl --status

echo
echo "Firmware Password:"
# Intel only: Apple Silicon has no firmware password (startup security is set
# in Recovery), so firmwarepasswd just errors there.
if [ "$(uname -m)" = "arm64" ]; then
    echo "  skipped (Apple Silicon)"
else
    sudo firmwarepasswd -check
fi

echo
echo "SSH Status:"
sudo systemsetup -getremotelogin

echo
echo "3️⃣  Objective-See monitors (must be RUNNING, not merely installed):"
for tool in LuLu OverSight BlockBlock ReiKey; do
    if pgrep -qi "$tool" 2>/dev/null; then
        printf '  ✓ %-12s running\n' "$tool"
    else
        printf '  ✗ %-12s NOT RUNNING — provides no protection\n' "$tool"
    fi
done

echo
echo "=========================================="
echo "  ✅ Audit Complete"
echo "=========================================="
echo "📋 Lynis report: $LYNIS_LOG"
echo
