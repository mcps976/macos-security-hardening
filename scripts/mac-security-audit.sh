#!/bin/bash
echo "=== macOS Security Audit ==="
echo
echo "1️⃣  Running Lynis audit..."
sudo lynis audit system --quick --no-colors | tee ~/logs/lynis-$(date +%Y%m%d).log
echo
echo "2️⃣  Checking security settings..."
echo "FileVault:" && fdesetup status
echo
echo "SIP:" && csrutil status
echo
echo "Firewall:" && sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
echo
echo "Gatekeeper:" && spctl --status
echo
echo "Firmware Password:" && sudo firmwarepasswd -check
echo
echo "✅ Audit Complete"
echo "📋 Report: ~/logs/lynis-$(date +%Y%m%d).log"
