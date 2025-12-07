#!/bin/bash
# macOS Complete Security Audit Script
# Runs all security checks and saves results

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create report directory in the calling user home
if [ -n "$SUDO_USER" ]; then
    REPORT_DIR="/Users/$SUDO_USER/security-audit-reports/$(date +%Y%m%d-%H%M%S)"
else
    REPORT_DIR="$HOME/security-audit-reports/$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$REPORT_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  macOS Complete Security Audit${NC}"
echo -e "${GREEN}  $(date)${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo "Report will be saved to: $REPORT_DIR"
echo

# Function to run command and save output
run_check() {
    local name="$1"
    local command="$2"
    local output_file="$3"
    
    echo -e "${YELLOW}Running: $name${NC}"
    eval "$command" > "$REPORT_DIR/$output_file" 2>&1
    echo -e "${GREEN}✓ Saved to $output_file${NC}"
    echo
}

# ============================================
# SYSTEM INFORMATION
# ============================================

echo "=== System Information ===" | tee "$REPORT_DIR/00-summary.txt"

run_check "System Info" "sw_vers && echo && uname -a && echo && uptime" "01-system-info.txt"
run_check "Disk Space" "df -h" "02-disk-space.txt"

# ============================================
# SECURITY TOOLS STATUS
# ============================================

echo "=== Security Tools Status ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "Running Security Tools" "ps aux | grep -i 'lulu\|oversight\|blockblock' | grep -v grep" "03-security-tools.txt"
run_check "Homebrew Security Packages" "brew list | grep -E 'clamav|lynis'" "04-homebrew-packages.txt"

# ============================================
# SYSTEM SECURITY
# ============================================

echo "=== System Security ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "Firewall Status" "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate" "05-firewall.txt"
run_check "FileVault Status" "fdesetup status" "06-filevault.txt"
run_check "SIP Status" "csrutil status" "07-sip.txt"
run_check "Gatekeeper Status" "spctl --status" "08-gatekeeper.txt"
run_check "Firmware Password" "sudo firmwarepasswd -check" "09-firmware.txt"
run_check "SSH Status" "sudo systemsetup -getremotelogin" "10-ssh.txt"

# ============================================
# INSTALLED APPLICATIONS
# ============================================

echo "=== Security Applications ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "Security Apps" "ls -la /Applications/ | grep -E 'LuLu|OverSight|BlockBlock|KnockKnock|ReiKey|Netiquette|AppCleaner'" "11-security-apps.txt"

# ============================================
# CLAMAV SCAN
# ============================================

echo "=== ClamAV Malware Scan ===" | tee -a "$REPORT_DIR/00-summary.txt"

echo -e "${YELLOW}Updating ClamAV definitions...${NC}"
timeout 120 freshclam -q > "$REPORT_DIR/12-clamav-update.txt" 2>&1 || echo "ClamAV update completed (or timed out after 2 min)"
echo -e "${GREEN}✓ ClamAV updated${NC}"
echo

echo -e "${YELLOW}Running malware scan (this may take up to 10 minutes)...${NC}"
timeout 600 clamscan -r ~/Downloads ~/Documents ~/Desktop --infected > "$REPORT_DIR/13-clamav-scan.txt" 2>&1 || echo "Scan completed (or timed out after 10 min)" >> "$REPORT_DIR/13-clamav-scan.txt"
echo -e "${GREEN}✓ ClamAV scan complete${NC}"
echo

# ============================================
# LYNIS AUDIT
# ============================================

echo "=== Lynis Security Audit ===" | tee -a "$REPORT_DIR/00-summary.txt"

echo -e "${YELLOW}Running Lynis audit (this may take a few minutes)...${NC}"
yes "" | sudo lynis audit system --quick --no-colors > "$REPORT_DIR/14-lynis-audit.txt" 2>&1
echo -e "${GREEN}✓ Lynis audit complete${NC}"
echo

# ============================================
# NETWORK SECURITY
# ============================================

echo "=== Network Security ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "Active Connections" "netstat -an | grep ESTABLISHED" "15-connections.txt"
run_check "Listening Services" "sudo lsof -iTCP -sTCP:LISTEN -n -P" "16-listening.txt"

# ============================================
# VPN STATUS
# ============================================

echo "=== VPN Status ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "Tailscale Status" "tailscale status 2>&1" "17-tailscale.txt"
run_check "Mullvad Status" "mullvad status 2>&1" "18-mullvad.txt"

# ============================================
# DNS CONFIGURATION
# ============================================

echo "=== DNS Configuration ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "DNS Servers" "scutil --dns | grep 'nameserver\[[0-9]*\]'" "19-dns.txt"

# ============================================
# SYSTEM LOGS
# ============================================

echo "=== System Logs ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "Security Logs" "log show --predicate 'eventMessage contains \"security\"' --info --last 1h | head -100" "20-security-logs.txt"

# ============================================
# HOMEBREW SECURITY
# ============================================

echo "=== Homebrew Security ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "Outdated Packages" "brew outdated" "21-outdated-packages.txt"
run_check "Homebrew Doctor" "brew doctor" "22-brew-doctor.txt"

# ============================================
# STARTUP ITEMS
# ============================================

echo "=== Startup Items ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "User Launch Agents" "ls -la ~/Library/LaunchAgents/" "23-launch-agents.txt"
run_check "System Launch Daemons" "sudo ls -la /Library/LaunchDaemons/ | head -30" "24-launch-daemons.txt"

# ============================================
# CUSTOM SCRIPTS
# ============================================

echo "=== Custom Maintenance Scripts ===" | tee -a "$REPORT_DIR/00-summary.txt"

run_check "Installed Scripts" "ls -la ~/bin/*.sh" "25-custom-scripts.txt"

# Run custom scripts if they exist
if [ -f ~/bin/mac-security-audit.sh ]; then
    run_check "Security Audit Script" "~/bin/mac-security-audit.sh" "26-security-audit.txt"
fi

if [ -f ~/bin/network-monitor.sh ]; then
    run_check "Network Monitor" "~/bin/network-monitor.sh" "27-network-monitor.txt"
fi

# ============================================
# CREATE SUMMARY
# ============================================

echo | tee -a "$REPORT_DIR/00-summary.txt"
echo "=== Audit Summary ===" | tee -a "$REPORT_DIR/00-summary.txt"
echo "Date: $(date)" | tee -a "$REPORT_DIR/00-summary.txt"
echo "Hostname: $(hostname)" | tee -a "$REPORT_DIR/00-summary.txt"
echo "Report Directory: $REPORT_DIR" | tee -a "$REPORT_DIR/00-summary.txt"
echo | tee -a "$REPORT_DIR/00-summary.txt"

# Quick summary of critical items
echo "=== Critical Security Items ===" | tee -a "$REPORT_DIR/00-summary.txt"
echo -n "FileVault: " | tee -a "$REPORT_DIR/00-summary.txt"
fdesetup status | tee -a "$REPORT_DIR/00-summary.txt"

echo -n "Firewall: " | tee -a "$REPORT_DIR/00-summary.txt"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | tee -a "$REPORT_DIR/00-summary.txt"

echo -n "SIP: " | tee -a "$REPORT_DIR/00-summary.txt"
csrutil status | tee -a "$REPORT_DIR/00-summary.txt"

echo -n "Gatekeeper: " | tee -a "$REPORT_DIR/00-summary.txt"
spctl --status | tee -a "$REPORT_DIR/00-summary.txt"

echo -n "Outdated Packages: " | tee -a "$REPORT_DIR/00-summary.txt"
brew outdated | wc -l | xargs echo | tee -a "$REPORT_DIR/00-summary.txt"

echo -n "ClamAV Threats Found: " | tee -a "$REPORT_DIR/00-summary.txt"
grep "Infected files:" "$REPORT_DIR/13-clamav-scan.txt" 2>/dev/null | tee -a "$REPORT_DIR/00-summary.txt"

# ============================================
# COMPLETION
# ============================================

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Audit Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo "Full report saved to: $REPORT_DIR"
echo
echo "Quick access:"
echo "  Summary:     cat $REPORT_DIR/00-summary.txt"
echo "  All reports: ls -la $REPORT_DIR"
echo
echo "To view all reports:"
echo "  cd $REPORT_DIR && ls -la"
echo
