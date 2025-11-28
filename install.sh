#!/bin/bash
# macOS Security Hardening Stack - Installation Script
# https://github.com/mcps976/macos-security-hardening

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=========================================="
echo "  macOS Security Hardening Stack"
echo "  Installation Script"
echo "=========================================="
echo

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found!"
    echo "Install from: https://brew.sh"
    exit 1
fi

# Create directories
echo "--- Creating directories ---"
mkdir -p ~/bin ~/logs
echo "✓ Directories created"
echo

# Update Homebrew
echo "--- Updating Homebrew ---"
brew update
echo

# Install security tools
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

echo
echo "--- Configuring ClamAV ---"

# Create config directory
sudo mkdir -p /opt/homebrew/etc/clamav

# Create freshclam.conf
sudo sh -c 'cat > /opt/homebrew/etc/clamav/freshclam.conf << "FRESHCLAM_EOF"
DatabaseDirectory /opt/homebrew/var/lib/clamav
UpdateLogFile /opt/homebrew/var/log/clamav/freshclam.log
DatabaseMirror database.clamav.net
FRESHCLAM_EOF'

# Create clamd.conf
sudo sh -c 'cat > /opt/homebrew/etc/clamav/clamd.conf << "CLAMD_EOF"
LogFile /opt/homebrew/var/log/clamav/clamd.log
PidFile /opt/homebrew/var/run/clamav/clamd.pid
DatabaseDirectory /opt/homebrew/var/lib/clamav
CLAMD_EOF'

# Create necessary directories
sudo mkdir -p /opt/homebrew/var/lib/clamav
sudo mkdir -p /opt/homebrew/var/log/clamav
sudo mkdir -p /opt/homebrew/var/run/clamav

# Set permissions
sudo chown -R $(whoami) /opt/homebrew/var/lib/clamav
sudo chown -R $(whoami) /opt/homebrew/var/log/clamav
sudo chown -R $(whoami) /opt/homebrew/var/run/clamav

echo "✓ ClamAV configured"

# Update virus definitions
echo "Updating ClamAV virus definitions (this may take a few minutes)..."
freshclam

echo "✓ ClamAV setup complete"
echo

# Install scripts
echo "--- Installing scripts ---"
cp "$SCRIPT_DIR/scripts/mac-cleanup.sh" ~/bin/
cp "$SCRIPT_DIR/scripts/clamscan-quick.sh" ~/bin/
cp "$SCRIPT_DIR/scripts/mac-security-audit.sh" ~/bin/
cp "$SCRIPT_DIR/scripts/weekly-maintenance.sh" ~/bin/
cp "$SCRIPT_DIR/scripts/network-monitor.sh" ~/bin/

chmod +x ~/bin/*.sh

echo "✓ Scripts installed to ~/bin/"
echo

# Add aliases if not present
echo "--- Adding aliases ---"
if ! grep -q "# macOS Security & Maintenance Aliases" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'ALIAS_EOF'

# macOS Security & Maintenance Aliases
alias cleanup='~/bin/mac-cleanup.sh'
alias scanmalware='~/bin/clamscan-quick.sh'
alias secaudit='~/bin/mac-security-audit.sh'
alias weekly='~/bin/weekly-maintenance.sh'
alias netmon='~/bin/network-monitor.sh'
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
echo "2. Launch always-on security tools:"
echo "   open -a LuLu"
echo "   open -a OverSight"
echo "   # BlockBlock starts automatically"
echo
echo "3. Configure LuLu:"
echo "   - Keep default settings (Allow Apple Programs, Allow Installed Programs)"
echo "   - Leave Passive Mode unchecked"
echo "   - You'll be alerted for new applications"
echo
echo "4. Run initial scans:"
echo "   scanmalware      # ClamAV malware scan"
echo "   scanstartup      # KnockKnock startup scan"
echo "   checkkeylog      # ReiKey keylogger check"
echo "   secaudit         # Full security audit"
echo
echo "📖 Documentation: https://github.com/mcps976/macos-security-hardening"
echo
echo "💰 You just saved \$89.95/year vs CleanMyMac!"
echo
