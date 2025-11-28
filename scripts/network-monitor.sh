#!/bin/bash
echo "=== Network Monitor ==="
echo
echo "--- Connections ---"
netstat -an | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20
echo
echo "--- Listening ---"
sudo lsof -iTCP -sTCP:LISTEN -n -P | awk 'NR>1 {print $9, $1}' | sort -u
echo
echo "--- Tailscale ---"
tailscale status 2>/dev/null | head -10 || echo "Not running"
echo
echo "--- Mullvad ---"
mullvad status 2>/dev/null || echo "CLI not found"
echo
echo "--- DNS ---"
scutil --dns | grep 'nameserver'
