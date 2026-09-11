#!/bin/bash
# macOS Cleanup Script - CleanMyMac Replacement
#
# FORENSICS NOTE: this script deliberately does NOT delete
# /Library/Logs/DiagnosticReports (crash reports), and no longer wipes cache
# or log directories wholesale. Crash reports are the first artefacts you
# examine after a BlockBlock, KnockKnock or LuLu alert — a security stack
# must not destroy them. Caches and user logs are age-limited instead.

set -uo pipefail

CACHE_AGE_DAYS=30   # remove cache files not accessed in this many days
LOG_AGE_DAYS=30     # remove user logs older than this

echo "=== macOS Cleanup ==="
echo

BEFORE=$(df -h / | awk 'NR==2 {print $4}')
echo "💾 Disk space before: $BEFORE available"
echo

# 1. Empty Trash
echo "🗑️  Emptying Trash..."
rm -rf ~/.Trash/* 2>/dev/null
echo "   ✓ Trash emptied"

# 2. Clear caches (age-limited, not wholesale)
echo "🧹 Clearing caches older than ${CACHE_AGE_DAYS} days..."
find ~/Library/Caches -type f -atime +${CACHE_AGE_DAYS} -delete 2>/dev/null
sudo find /Library/Caches -type f -atime +${CACHE_AGE_DAYS} -delete 2>/dev/null
echo "   ✓ Stale caches cleared"

# 3. Clear DNS cache
echo "🌐 Clearing DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
echo "   ✓ DNS cache cleared"

# 4. Trim old user logs — crash reports PRESERVED
echo "📋 Trimming user logs older than ${LOG_AGE_DAYS} days..."
find ~/Library/Logs -type f -mtime +${LOG_AGE_DAYS} -delete 2>/dev/null
echo "   ✓ Old user logs trimmed (DiagnosticReports preserved)"

# 5. Homebrew cleanup
if command -v brew &> /dev/null; then
    echo "🍺 Cleaning Homebrew..."
    brew cleanup -s 2>/dev/null
    brew autoremove 2>/dev/null
    BREW_CACHE="$(brew --cache 2>/dev/null)"
    if [ -n "$BREW_CACHE" ] && [ -d "$BREW_CACHE" ]; then
        rm -rf "$BREW_CACHE" 2>/dev/null
    fi
    echo "   ✓ Homebrew cleaned"
fi

# 6. Xcode cleanup (if present)
if [ -d ~/Library/Developer/Xcode ]; then
    echo "🔨 Clearing Xcode cache..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
    rm -rf ~/Library/Developer/Xcode/Archives/* 2>/dev/null
    echo "   ✓ Xcode cache cleared"
fi

# 7. Node cleanup (if present)
if command -v npm &> /dev/null; then
    echo "📦 Cleaning npm cache..."
    npm cache clean --force 2>/dev/null
    echo "   ✓ npm cache cleared"
fi

# 8. Old iOS backups (prompted — never automatic)
if [ -d ~/Library/Application\ Support/MobileSync/Backup ]; then
    BACKUP_SIZE=$(du -sh ~/Library/Application\ Support/MobileSync/Backup 2>/dev/null | awk '{print $1}')
    if [ -n "$BACKUP_SIZE" ]; then
        echo "📱 iOS backups: $BACKUP_SIZE"
        read -p "   Remove old iOS backups? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf ~/Library/Application\ Support/MobileSync/Backup/* 2>/dev/null
            echo "   ✓ iOS backups removed"
        else
            echo "   ⊘ Skipped iOS backups"
        fi
    fi
fi

# 9. Purge inactive memory
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
