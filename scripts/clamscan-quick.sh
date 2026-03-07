#!/bin/bash
echo "=== ClamAV Malware Scan ==="
echo

LOG_FILE="/tmp/clamav-scan-$(date +%Y%m%d).log"

echo "📡 Updating virus definitions..."
if ! freshclam --quiet 2>/dev/null; then
    echo "⚠️  freshclam update failed — continuing with existing definitions"
fi

echo "🔍 Scanning Downloads, Documents, Desktop..."
clamscan -r ~/Downloads ~/Documents ~/Desktop --infected --bell --log="$LOG_FILE"
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
