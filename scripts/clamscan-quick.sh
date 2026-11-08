#!/bin/bash
echo "=== ClamAV Malware Scan ==="
echo

LOG_FILE="/tmp/clamav-scan-$(date +%Y%m%d).log"

# Cisco's package, not Homebrew (Cisco-Talos/clamav#1887, PR #1873; see
# freshclam-run.sh). Revert CLAMAV_BIN to /opt/homebrew/bin once Homebrew ships a fix.
CLAMAV_BIN="/usr/local/clamav/bin"
CLAMAV_CONF="/opt/homebrew/etc/clamav/freshclam.conf"
CLAMAV_DB="/opt/homebrew/var/lib/clamav"
CLAMAV_LOG="/opt/homebrew/var/log/clamav/freshclam.log"

# Definition version and build date, e.g. "ClamAV 1.5.4/28124/Wed Sep 16 ...".
# Printed before and after so a stale database is visible rather than silent —
# the daily LaunchAgent (schedule-freshclam.sh) should already have done the
# update; this call is the belt to that brace.
defs() { "$CLAMAV_BIN/freshclam" --config-file="$CLAMAV_CONF" --version 2>/dev/null | cut -d/ -f2-; }

echo "📡 Updating virus definitions (before: $(defs))..."
if ! "$CLAMAV_BIN/freshclam" --config-file="$CLAMAV_CONF" --quiet 2>/dev/null; then
    echo "⚠️  freshclam update failed — continuing with existing definitions"
    echo "    see $CLAMAV_LOG"
fi
echo "   Definitions: $(defs)"

echo "🔍 Scanning Downloads, Documents, Desktop..."
"$CLAMAV_BIN/clamscan" --database="$CLAMAV_DB" -r ~/Downloads ~/Documents ~/Desktop --infected --bell --log="$LOG_FILE"
echo

echo "✅ Scan complete"
echo "📋 Log: $LOG_FILE"
echo

INFECTED=$(grep "Infected files:" "$LOG_FILE" | awk '{print $3}')
if [ "$INFECTED" != "0" ]; then
    echo "⚠️  WARNING: $INFECTED infected files found!"
else
    echo "✓ No infections found"
fi
