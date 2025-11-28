#!/bin/bash
echo "=== macOS Cleanup ==="
echo
BEFORE=$(df -h / | awk 'NR==2 {print $4}')
echo "💾 Disk space before: $BEFORE available"
echo
echo "🗑️  Emptying Trash..."
rm -rf ~/.Trash/*
echo "   ✓ Trash emptied"
echo "🧹 Clearing caches..."
sudo rm -rf /Library/Caches/* 2>/dev/null
rm -rf ~/Library/Caches/* 2>/dev/null
echo "   ✓ System caches cleared"
echo "🌐 Clearing DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
echo "   ✓ DNS cache cleared"
echo "📋 Clearing old logs..."
sudo rm -rf /private/var/log/asl/*.asl 2>/dev/null
sudo rm -rf /Library/Logs/DiagnosticReports/* 2>/dev/null
rm -rf ~/Library/Logs/* 2>/dev/null
echo "   ✓ Old logs cleared"
if command -v brew &> /dev/null; then
    echo "🍺 Cleaning Homebrew..."
    brew cleanup -s 2>/dev/null
    brew autoremove 2>/dev/null
    rm -rf $(brew --cache) 2>/dev/null
    echo "   ✓ Homebrew cleaned"
fi
echo "💾 Purging inactive memory..."
sudo purge
echo "   ✓ Memory purged"
AFTER=$(df -h / | awk 'NR==2 {print $4}')
echo
echo "=========================================="
echo "  ✅ Cleanup Complete"
echo "=========================================="
echo "💾 Disk space before: $BEFORE available"
echo "💾 Disk space after:  $AFTER available"
echo
