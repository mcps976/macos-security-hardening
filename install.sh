#!/bin/bash
# macOS Security Hardening Stack - Installation Script
# Repo: git@github.com:mcps976/macos-security-hardening.git
#
# Scripts are SYMLINKED into ~/bin, not copied. The repo is the single source
# of truth — editing either location edits the same file, and `git status`
# shows the change. (Copying previously produced three divergent versions.)

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=========================================="
echo "  macOS Security Hardening Stack"
echo "  Installation Script"
echo "=========================================="
echo

if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found!"
    echo "Install from: https://brew.sh"
    exit 1
fi

echo "--- Creating directories ---"
mkdir -p ~/bin ~/logs
echo "✓ Directories created"
echo

echo "--- Updating Homebrew ---"
brew update
echo

echo "--- Installing Security Tools ---"
echo

echo "Installing LuLu (Network Firewall)..."
brew install --cask lulu

echo "Installing OverSight (Camera/Mic Monitor)..."
brew install --cask oversight

echo "Installing BlockBlock (Persistence Monitor)..."
brew install --cask blockblock

echo "Installing KnockKnock (Startup Scanner)..."
brew install --cask knockknock

echo "Installing ReiKey (Keylogger Detector)..."
brew install --cask reikey

echo "Installing Netiquette (Network Viewer)..."
brew install --cask netiquette

echo "Installing ClamAV (Anti-Malware)..."
brew install clamav

echo "Installing Lynis (Security Auditor)..."
brew install lynis

echo "Installing AppCleaner (Uninstaller)..."
brew install --cask appcleaner

# REQUIRED: macOS has no native `timeout`. Without coreutils the audit
# script's ClamAV steps silently no-op while printing success.
echo "Installing coreutils (provides 'timeout' — required by run_full_audit.sh)..."
brew install coreutils

echo
echo "--- Configuring ClamAV ---"
# Delegated to fix-clamav.sh rather than duplicated inline
"$SCRIPT_DIR/scripts/fix-clamav.sh"
echo

echo "--- Scheduling ClamAV definition updates ---"
# Daily LaunchAgent. Without it, definitions only update when someone runs
# `scanmalware` — and between April and September 2026 nobody did.
"$SCRIPT_DIR/scripts/schedule-freshclam.sh"
echo

echo "--- Linking scripts into ~/bin ---"
for s in mac-cleanup clamscan-quick mac-security-audit weekly-maintenance network-monitor fix-clamav schedule-freshclam; do
    ln -sf "$SCRIPT_DIR/scripts/$s.sh" ~/bin/"$s.sh"
    echo "  ✓ ~/bin/$s.sh -> repo"
done
chmod +x "$SCRIPT_DIR"/scripts/*.sh
echo

echo "--- Adding aliases ---"
if ! grep -q "# macOS Security & Maintenance Aliases" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'ALIAS_EOF'

# macOS Security & Maintenance Aliases
alias cleanup='~/bin/mac-cleanup.sh'
alias scanmalware='~/bin/clamscan-quick.sh'
alias secaudit='~/bin/mac-security-audit.sh'
alias weekly='~/bin/weekly-maintenance.sh'
alias netmon='~/bin/network-monitor.sh'
alias fullaudit='~/Git/macos/macos-security-hardening/scripts/run_full_audit.sh'
alias scanstartup='open -a KnockKnock'
alias checkkeylog='open -a ReiKey'
alias viewnetwork='open -a Netiquette'
alias uninstall='open -a AppCleaner'
ALIAS_EOF
    echo "✓ Aliases added to ~/.zshrc"
else
    echo "⊘ Aliases already exist in ~/.zshrc"
fi

echo
echo "=========================================="
echo "  ✅ Installation Complete!"
echo "=========================================="
echo
echo "🚀 Next Steps:"
echo
echo "1. Reload your shell:"
echo "   source ~/.zshrc"
echo
echo "2. Launch the always-on monitors:"
echo "   open -a LuLu"
echo "   open -a OverSight"
echo "   open -a ReiKey        # ⚠ must RUN to detect anything"
echo "   # BlockBlock starts automatically via its launch daemon"
echo
echo "3. Set each monitor to start at login (in its own preferences)."
echo "   An installed-but-not-running monitor provides ZERO protection."
echo
echo "4. Configure LuLu:"
echo "   - Leave Passive Mode unchecked"
echo "   - Consider disabling 'Allow DNS' — it is the setting that surfaces"
echo "     a process talking to an unexpected resolver"
echo
echo "5. Enable BlockBlock's ClickFix detection (fake-CAPTCHA paste attacks)."
echo
echo "6. Run initial scans:"
echo "   secaudit         # Lynis + system security + monitor status"
echo "   fullaudit        # Everything, saved to ~/security-audit-reports/"
echo "   netmon           # Topology-aware network posture"
echo "   scanmalware      # ClamAV scan"
echo
echo "📖 Documentation: README.md in this repo"
echo
