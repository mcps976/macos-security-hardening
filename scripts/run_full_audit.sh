#!/bin/bash
# macOS Complete Security Audit
#
# COMPOSITION RULE: this script CALLS mac-security-audit.sh and
# network-monitor.sh rather than repeating their commands. Previously a single
# run executed Lynis twice and repeated FileVault/SIP/firewall/Gatekeeper three
# times each. Do not re-add inline copies of those checks — add them to the
# relevant sub-script instead, and it will be captured here automatically.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

KEEP_REPORTS=10   # how many timestamped report dirs to retain

# Homebrew upgrade behaviour. The audit is read-only by default: upgrading
# mid-run would change the very state being measured. Any upgrade therefore
# happens AFTER every capture is complete.
#   auto (default) — prompt if outdated packages exist and a terminal is present
#   --upgrade      — upgrade without prompting
#   --no-upgrade   — never upgrade, just report
DO_UPGRADE=auto
for arg in "$@"; do
    case "$arg" in
        --upgrade)    DO_UPGRADE=yes ;;
        --no-upgrade) DO_UPGRADE=no ;;
        -h|--help)
            echo "usage: run_full_audit.sh [--upgrade | --no-upgrade]"
            echo "  --upgrade     run 'brew upgrade' after the audit if packages are outdated"
            echo "  --no-upgrade  report outdated packages but never upgrade"
            echo "  (default: prompt when outdated packages exist and stdin is a terminal)"
            exit 0 ;;
        *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
    esac
done

# Report dir in the calling user's home, even under sudo
if [ -n "${SUDO_USER:-}" ]; then
    REPORT_ROOT="/Users/$SUDO_USER/security-audit-reports"
else
    REPORT_ROOT="$HOME/security-audit-reports"
fi
REPORT_DIR="$REPORT_ROOT/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPORT_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  macOS Complete Security Audit${NC}"
echo -e "${GREEN}  $(date)${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo "Report: $REPORT_DIR"
echo

run_check() {
    local name="$1" cmd="$2" out="$3"
    echo -e "${YELLOW}Running: $name${NC}"
    eval "$cmd" > "$REPORT_DIR/$out" 2>&1
    echo -e "${GREEN}✓ $out${NC}"
    echo
}

SUMMARY="$REPORT_DIR/00-summary.txt"

# ============================================
# SYSTEM INFORMATION
# ============================================
echo "=== System Information ===" | tee "$SUMMARY"
run_check "System Info" "sw_vers && echo && uname -a && echo && uptime" "01-system-info.txt"
run_check "Disk Space" "df -h" "02-disk-space.txt"

# ============================================
# SECURITY TOOL STATUS
# ============================================
echo "=== Security Tools ===" | tee -a "$SUMMARY"
# ReiKey included — it is a real-time monitor and its absence is a finding
run_check "Running Security Tools" \
    "ps aux | grep -iE 'lulu|oversight|blockblock|reikey' | grep -v grep" \
    "03-security-tools.txt"
run_check "Security System Extensions" "systemextensionsctl list" "04-system-extensions.txt"
run_check "Homebrew Security Packages" "brew list | grep -E 'clamav|lynis|coreutils'" "05-homebrew-packages.txt"
run_check "Security Apps Installed" \
    "ls -la /Applications/ | grep -E 'LuLu|OverSight|BlockBlock|KnockKnock|ReiKey|Netiquette|AppCleaner'" \
    "06-security-apps.txt"

# ============================================
# SYSTEM SECURITY  (composed — includes Lynis)
# ============================================
echo "=== System Security (via mac-security-audit.sh) ===" | tee -a "$SUMMARY"
echo -e "${YELLOW}Running full security audit — Lynis included, this takes a few minutes...${NC}"
"$SCRIPT_DIR/mac-security-audit.sh" > "$REPORT_DIR/07-security-audit.txt" 2>&1
echo -e "${GREEN}✓ 07-security-audit.txt${NC}"
echo

# ============================================
# MALWARE SCAN
# ============================================
echo "=== ClamAV Malware Scan ===" | tee -a "$SUMMARY"
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN=gtimeout
else
    TIMEOUT_BIN=""
    echo -e "${RED}⚠ 'timeout' not found (brew install coreutils) — running uncapped${NC}"
fi

echo -e "${YELLOW}Updating ClamAV definitions...${NC}"
${TIMEOUT_BIN:+$TIMEOUT_BIN 120} freshclam -q > "$REPORT_DIR/08-clamav-update.txt" 2>&1 \
    || echo "freshclam exited non-zero (update failed or timed out)" >> "$REPORT_DIR/08-clamav-update.txt"

echo -e "${YELLOW}Scanning Downloads/Documents/Desktop (up to 10 min)...${NC}"
${TIMEOUT_BIN:+$TIMEOUT_BIN 600} clamscan -r ~/Downloads ~/Documents ~/Desktop --infected \
    > "$REPORT_DIR/09-clamav-scan.txt" 2>&1 \
    || echo "clamscan exited non-zero (findings or timeout)" >> "$REPORT_DIR/09-clamav-scan.txt"
echo -e "${GREEN}✓ 09-clamav-scan.txt${NC}"
echo

# ============================================
# NETWORK  (composed — topology-aware)
# ============================================
echo "=== Network (via network-monitor.sh) ===" | tee -a "$SUMMARY"
"$SCRIPT_DIR/network-monitor.sh" > "$REPORT_DIR/10-network-monitor.txt" 2>&1
echo -e "${GREEN}✓ 10-network-monitor.txt${NC}"
echo

# ============================================
# LOGS, PACKAGES, PERSISTENCE
# ============================================
echo "=== Logs / Packages / Persistence ===" | tee -a "$SUMMARY"
run_check "Security Logs" \
    "log show --predicate 'eventMessage contains \"security\"' --info --last 1h | head -100" \
    "11-security-logs.txt"
run_check "Outdated Packages" "brew outdated" "12-outdated-packages.txt"
run_check "Homebrew Doctor" "brew doctor" "13-brew-doctor.txt"
run_check "User Launch Agents" "ls -la ~/Library/LaunchAgents/" "14-launch-agents.txt"
run_check "System Launch Daemons" "sudo ls -la /Library/LaunchDaemons/" "15-launch-daemons.txt"

# ============================================
# CLEANUP CANDIDATES
# ============================================
echo "=== Cleanup Candidates ===" | tee -a "$SUMMARY"
run_check "Old Preference Files" "find ~/Library/Preferences -name '*.plist' -mtime +90 2>/dev/null | head -20" "16-old-preferences.txt"
run_check "Large Cache Files" "du -sh ~/Library/Caches/* 2>/dev/null | sort -h | tail -20" "17-large-caches.txt"
run_check "Old Application Support" "find ~/Library/Application\\ Support -type d -mtime +180 -maxdepth 1 2>/dev/null" "18-old-app-support.txt"
run_check "Homebrew Cleanup Needed" "brew cleanup -n 2>&1" "19-brew-cleanup.txt"
run_check "Old Downloads" "find ~/Downloads -type f -mtime +90 2>/dev/null | wc -l" "20-old-downloads.txt"
run_check "Installed Scripts" "ls -la ~/bin/*.sh" "21-custom-scripts.txt"

# ============================================
# SUMMARY  (parsed from captured output — nothing re-run)
# ============================================
{
    echo
    echo "=== Audit Summary ==="
    echo "Date:     $(date)"
    echo "Hostname: $(hostname)"
    echo "Report:   $REPORT_DIR"
    echo
    echo "=== Critical Security Items ==="
    grep -A1 '^FileVault:'          "$REPORT_DIR/07-security-audit.txt" | tail -1 | sed 's/^/FileVault:  /'
    grep -A1 '^SIP'                 "$REPORT_DIR/07-security-audit.txt" | tail -1 | sed 's/^/SIP:        /'
    grep -A1 '^Firewall:'           "$REPORT_DIR/07-security-audit.txt" | tail -1 | sed 's/^/Firewall:   /'
    grep -A1 '^Gatekeeper:'         "$REPORT_DIR/07-security-audit.txt" | tail -1 | sed 's/^/Gatekeeper: /'
    echo
    echo "=== Monitors Not Running ==="
    # Match our own sentinel, not the bare string: Lynis also prints
    # "[ NOT RUNNING ]" for its daemon checks, which produced a false positive.
    grep 'provides no protection' "$REPORT_DIR/07-security-audit.txt" \
        || echo "  (all four Objective-See monitors running)"
    echo
    echo -n "Outdated Packages: "; wc -l < "$REPORT_DIR/12-outdated-packages.txt" | tr -d ' '
    echo -n "ClamAV: "; grep 'Infected files:' "$REPORT_DIR/09-clamav-scan.txt" 2>/dev/null || echo "see 09-clamav-scan.txt"
    echo
    echo "=== Egress / VPN ==="
    grep -E 'public IP|exit node|backend' "$REPORT_DIR/10-network-monitor.txt" 2>/dev/null || true
} | tee -a "$SUMMARY"

# ============================================
# RETENTION
# ============================================
PRUNED=$(ls -1dt "$REPORT_ROOT"/*/ 2>/dev/null | tail -n +$((KEEP_REPORTS + 1)))
if [ -n "$PRUNED" ]; then
    echo "$PRUNED" | while read -r d; do rm -rf "$d"; done
    echo
    echo "🗑  Pruned $(echo "$PRUNED" | wc -l | tr -d ' ') old report dir(s), keeping newest $KEEP_REPORTS"
fi

# ============================================
# HOMEBREW UPGRADE  (post-capture, opt-in)
# ============================================
OUTDATED_COUNT=$(grep -c . "$REPORT_DIR/12-outdated-packages.txt" 2>/dev/null || echo 0)

if [ "${OUTDATED_COUNT:-0}" -gt 0 ] && [ "$DO_UPGRADE" != "no" ]; then
    echo
    echo -e "${YELLOW}${OUTDATED_COUNT} outdated Homebrew package(s):${NC}"
    sed 's/^/    /' "$REPORT_DIR/12-outdated-packages.txt" | head -15
    [ "$OUTDATED_COUNT" -gt 15 ] && echo "    … and $((OUTDATED_COUNT - 15)) more"
    echo

    RUN_UPGRADE=no
    if [ "$DO_UPGRADE" = "yes" ]; then
        RUN_UPGRADE=yes
    elif [ -t 0 ]; then
        read -p "  Run 'brew update && brew upgrade' now? [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && RUN_UPGRADE=yes
    else
        echo "  (non-interactive — skipping. Re-run with --upgrade to apply.)"
    fi

    if [ "$RUN_UPGRADE" = "yes" ]; then
        echo -e "${YELLOW}Updating Homebrew...${NC}"
        {
            echo "=== brew update/upgrade — $(date) ==="
            brew update 2>&1
            echo
            brew upgrade 2>&1
        } | tee "$REPORT_DIR/22-brew-upgrade.txt"
        echo -e "${GREEN}✓ 22-brew-upgrade.txt${NC}"
        echo -n "  Remaining outdated: " | tee -a "$SUMMARY"
        brew outdated | grep -c . | tee -a "$SUMMARY"
    else
        echo "  ⊘ Skipped — packages left outdated"
    fi
elif [ "${OUTDATED_COUNT:-0}" -eq 0 ]; then
    echo
    echo -e "${GREEN}✓ All Homebrew packages up to date${NC}"
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Audit Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo "  Summary: cat $SUMMARY"
echo "  Reports: ls -la $REPORT_DIR"
echo
