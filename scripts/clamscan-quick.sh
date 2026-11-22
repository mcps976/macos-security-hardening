#!/bin/bash
# ClamAV scan: the one scanner every other script calls (scanmalware, weekly,
# run_full_audit.sh), so the scan list and the failure check live here only.
#
#   clamscan-quick.sh          quick: Downloads, Documents, Desktop, Nextcloud
#   clamscan-quick.sh --full   full: home folder and system locations (hours)
#
# Exit codes: 0 clean, 1 infected files found, 2 scan failed.
# Optional: LOG_FILE=… chooses where clamscan's log goes.

FULL=0
[ "${1:-}" = "--full" ] && FULL=1

echo "=== ClamAV Malware Scan ($( [ $FULL -eq 1 ] && echo full || echo quick )) ==="
echo

# Under sudo (run_full_audit.sh), scan the invoking user's home, not root's.
if [ -n "${SUDO_USER:-}" ]; then USER_HOME="/Users/$SUDO_USER"; else USER_HOME="$HOME"; fi

# Homebrew's ClamAV again since 1.5.5 (OpenSSL 4 fix for Cisco-Talos/clamav#1887,
# 2026-11-22). Cisco's package in /usr/local/clamav stays installed as the rollback.
CLAMAV_BIN="/opt/homebrew/bin"
CLAMAV_CONF="/opt/homebrew/etc/clamav/freshclam.conf"
CLAMAV_DB="/opt/homebrew/var/lib/clamav"
CLAMAV_LOG="/opt/homebrew/var/log/clamav/freshclam.log"

if [ $FULL -eq 1 ]; then
    LOG_FILE="${LOG_FILE:-$USER_HOME/logs/clamscan-full-$(date +%Y%m%d).log}"
    # Everything a file could be put into, except: media (Martin, 2026-11-12:
    # photos and music are an unlikely carrier and double the time; downloads
    # land in Downloads, which is scanned), caches, ClamAV's own signature
    # files and their backups (a scanner reading signatures flags them), cloud
    # placeholders (reading one would download it), and /System, macOS's
    # sealed volume, verified at every boot. /Volumes (external disks, Time
    # Machine) is never a start point.
    TARGETS=("$USER_HOME" /Applications /Library /opt/homebrew /usr/local /Users/Shared /private/tmp)
    EXCLUDES=(
        "^$USER_HOME/(Pictures|Music)/"
        "^$USER_HOME/Library/(Caches|CloudStorage|Mobile Documents)/"
        "^$USER_HOME/\\.cache/"
        "^$USER_HOME/clamav-db-backup"
        "^/opt/homebrew/var/lib/clamav/"
        "^/usr/local/clamav/"
        "^/Library/Caches/"
    )
else
    LOG_FILE="${LOG_FILE:-/tmp/clamav-scan-$(date +%Y%m%d).log}"
    TARGETS=("$USER_HOME/Downloads" "$USER_HOME/Documents" "$USER_HOME/Desktop")
    # The Nextcloud client keeps its files local (no placeholders), so a scan
    # reads copies on disk and downloads nothing (checked 2026-11-12).
    [ -d "$USER_HOME/Nextcloud" ] && TARGETS+=("$USER_HOME/Nextcloud")
    EXCLUDES=()
fi
mkdir -p "$(dirname "$LOG_FILE")"

# Definition version and build date, e.g. "ClamAV 1.5.4/28124/Wed Sep 16 ...".
# Printed before and after so a stale database is visible rather than silent —
# the daily LaunchAgent (schedule-freshclam.sh) should already have done the
# update; this call is the belt to that brace.
# Under sudo (run_full_audit.sh), update as the invoking user so the database
# stays theirs: as root, freshclam drops to DatabaseOwner (macOS's _clamav),
# which can't write the user-owned database folder, so the update would fail.
FRESHCLAM=("$CLAMAV_BIN/freshclam")
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    FRESHCLAM=(sudo -u "$SUDO_USER" "${FRESHCLAM[@]}")
fi
defs() { "${FRESHCLAM[@]}" --config-file="$CLAMAV_CONF" --version 2>/dev/null | cut -d/ -f2-; }

echo "📡 Updating virus definitions (before: $(defs))..."
if ! "${FRESHCLAM[@]}" --config-file="$CLAMAV_CONF" --quiet 2>/dev/null; then
    echo "⚠️  freshclam update failed — continuing with existing definitions"
    echo "    see $CLAMAV_LOG"
fi
echo "   Definitions: $(defs)"

EXCLUDE_ARGS=()
for e in "${EXCLUDES[@]}"; do EXCLUDE_ARGS+=(--exclude-dir="$e"); done

echo "🔍 Scanning: ${TARGETS[*]}"
[ $FULL -eq 1 ] && echo "   (excluding media, caches, cloud placeholders and ClamAV's own files; this takes hours)"
"$CLAMAV_BIN/clamscan" --database="$CLAMAV_DB" -r --infected --bell \
    "${EXCLUDE_ARGS[@]}" --log="$LOG_FILE" "${TARGETS[@]}"
RC=$?   # clamscan: 0 clean, 1 infected, 2 error (including any unreadable file)
echo

# A scan that can't load its database still prints "Infected files: 0", which
# is how the scanner failed silently from 2026-10-26 to 2026-11-08. A failed
# scan is a missing summary, "Known viruses: 0" or nothing scanned, worded with
# "FAIL" so weekly-maintenance-run.sh alerts on it. Exit 2 alone isn't one: a
# full scan always meets files the user may not read, which clamscan counts
# as errors ("Total errors").
KNOWN=$(grep "Known viruses:" "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $3}')
INFECTED=$(grep "Infected files:" "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $3}')
SCANNED=$(grep "Scanned files:" "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $3}')
ERRORS=$(grep "Total errors:" "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $3}')
echo "📋 Log: $LOG_FILE"
echo
if [ -z "$INFECTED" ] || [ -z "$KNOWN" ] || [ "$KNOWN" = "0" ] || [ "${SCANNED:-0}" = "0" ]; then
    echo "❌ SCAN FAILED: clamscan exit $RC, Known viruses: ${KNOWN:-none}, Scanned files: ${SCANNED:-none}, Infected files: ${INFECTED:-none}"
    exit 2
fi
echo "✅ Scan complete (Known viruses: $KNOWN, scanned files: $SCANNED)"
[ -n "$ERRORS" ] && [ "$ERRORS" != "0" ] && echo "   $ERRORS file(s) couldn't be read (permissions); see the log"
if [ "$INFECTED" != "0" ]; then
    echo "⚠️  WARNING: $INFECTED infected files found!"
    exit 1
fi
echo "✓ No infections found"
