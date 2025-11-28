#!/bin/bash
echo "=== Weekly Maintenance ==="
~/bin/mac-cleanup.sh
echo "🍺 Updating Homebrew..."
brew update && brew upgrade && brew cleanup
~/bin/clamscan-quick.sh
softwareupdate -l
echo "✅ Complete"
