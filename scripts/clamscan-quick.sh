#!/bin/bash
echo "=== ClamAV Malware Scan ==="
echo
echo "📡 Updating virus definitions..."
freshclam -q
echo "🔍 Scanning Downloads, Documents, Desktop..."
clamscan -r ~/Downloads ~/Documents ~/Desktop --infected --bell --log=/tmp/clamav-scan-$(date +%Y%m%d).log
echo
echo "✅ Scan complete"
echo "📋 Log: /tmp/clamav-scan-$(date +%Y%m%d).log"
echo
INFECTED=$(grep "Infected files:" /tmp/clamav-scan-$(date +%Y%m%d).log | awk '{print $3}')
if [ "$INFECTED" != "0" ]; then
    echo "⚠️  WARNING: $INFECTED infected files found!"
else
    echo "✓ No infections found"
fi
