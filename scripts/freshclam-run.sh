#!/bin/bash
# freshclam-run.sh — launchd wrapper for freshclam
#
# Runs freshclam, then sends ONE notification if the definitions are older than
# MAX_AGE_DAYS (default 3), otherwise nothing: silence means healthy. It checks
# the age of the definitions, not freshclam's exit code. That also catches the job
# not running at all, and a single network blip doesn't trigger an alert.
#
# Background: freshclam failed every day from 26 October 2026 (ClamAV 1.5.4
# with OpenSSL 4 rejected database signatures) and nothing said so for six days.
#
# ClamAV binaries come from Cisco's official macOS package (/usr/local/clamav),
# not Homebrew: Homebrew's clamav 1.5.4_1 links OpenSSL 4.1 and rejects every
# database signature (Cisco-Talos/clamav#1887, fix in PR #1873). Homebrew's
# freshclam.conf and database directory are still used. When a fixed clamav
# lands in Homebrew, set CLAMAV_BIN back to /opt/homebrew/bin.
#
# Notification target lives OUTSIDE the repo (this repo is public):
#   ~/.config/macos-security-hardening/notify.conf   — see scripts/notify.conf.example
# Without that file the run still happens; it just logs instead of notifying.
# Output goes to launchd's StandardOutPath (~/logs/freshclam-launchd.log).

set -uo pipefail

CONF="${NOTIFY_CONF:-$HOME/.config/macos-security-hardening/notify.conf}"
MAX_AGE_DAYS="${MAX_AGE_DAYS:-3}"

CLAMAV_BIN="/usr/local/clamav/bin"
CLAMAV_CONF="/opt/homebrew/etc/clamav/freshclam.conf"   # DatabaseDirectory, UpdateLogFile

NTFY_URL=""
NTFY_TOKEN_FILE=""
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"

notify() {   # $1 title, $2 priority, $3 tags; body on stdin
    local body; body="$(cat)"
    if [ -z "$NTFY_URL" ]; then echo "notify: no NTFY_URL in $CONF — not sent"; return 0; fi
    local auth=()
    [ -n "$NTFY_TOKEN_FILE" ] && [ -r "$NTFY_TOKEN_FILE" ] && auth=(-H "Authorization: Bearer $(cat "$NTFY_TOKEN_FILE")")
    # curl exits 0 on an HTTP error (no -f), so check the status: a dead token
    # (401) went unnoticed for days in October 2026.
    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "${auth[@]}" \
        -H "Title: $1" -H "Priority: $2" -H "Tags: $3" \
        --data-binary "$body" "$NTFY_URL") \
        || { echo "notify: curl failed (network)"; return 1; }
    [ "$code" = 200 ] || { echo "notify: ntfy returned HTTP $code — not delivered"; return 1; }
}

echo "### run started $(date '+%Y-%m-%d %H:%M')"
"$CLAMAV_BIN/freshclam" --config-file="$CLAMAV_CONF" --quiet
rc=$?
echo "### freshclam exit $rc"

# "ClamAV 1.5.4/28163/Sat Oct 24 14:26:10 2026": the third field is the build
# time of the daily database. Ask freshclam with the config file: it reads
# DatabaseDirectory from it, whereas the package's clamscan never reads
# freshclam.conf and would report on its own empty database directory.
built="$("$CLAMAV_BIN/freshclam" --config-file="$CLAMAV_CONF" --version 2>/dev/null | cut -d/ -f3)"
built_epoch="$(LC_ALL=C date -j -f '%a %b %d %T %Y' "$built" +%s 2>/dev/null)"

if [ -z "$built_epoch" ]; then
    echo "### could not read the definitions date from freshclam --version"
    printf 'freshclam exit %s; freshclam --version gave no readable date (%s).\nLog: ~/logs/freshclam-launchd.log' "$rc" "$built" \
        | notify "ClamAV: definitions date unreadable" high "warning,apple"
    exit 1
fi

age_days=$(( ($(date +%s) - built_epoch) / 86400 ))
echo "### definitions built $built ($age_days days old)"

if [ "$age_days" -gt "$MAX_AGE_DAYS" ]; then
    printf 'Definitions are %s days old (built %s); freshclam exit %s.\nLog: ~/logs/freshclam-launchd.log' "$age_days" "$built" "$rc" \
        | notify "ClamAV: definitions ${age_days} days old" high "warning,apple"
fi
exit 0
