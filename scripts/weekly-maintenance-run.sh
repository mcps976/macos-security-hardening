#!/bin/bash
# weekly-maintenance-run.sh — launchd wrapper for weekly-maintenance.sh --unattended
#
# Keeps a dated log under ~/logs/weekly-maintenance/ and sends ONE notification
# only when there is something for a person to do: outdated Homebrew packages,
# macOS updates available, an infected file, or a scan/update error. A week with
# nothing to do is silent; the dated log is the proof it ran.
#
# Notification target lives OUTSIDE the repo (this repo is public):
#   ~/.config/macos-security-hardening/notify.conf   — see scripts/notify.conf.example
# Without that file the run still happens; it just logs instead of notifying.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="$HOME/logs/weekly-maintenance"
CONF="${NOTIFY_CONF:-$HOME/.config/macos-security-hardening/notify.conf}"

mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$(date +%Y-%m-%d).log"

NTFY_URL=""; NTFY_TOKEN_FILE=""
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"

notify() {   # $1 title, $2 priority, $3 tags; body on stdin
    local body; body=$(cat)
    if [ -z "$NTFY_URL" ]; then echo "notify: no NTFY_URL in $CONF — not sent" >> "$LOG"; return 0; fi
    local auth=()
    [ -n "$NTFY_TOKEN_FILE" ] && [ -r "$NTFY_TOKEN_FILE" ] && auth=(-H "Authorization: Bearer $(cat "$NTFY_TOKEN_FILE")")
    curl -sS -o /dev/null --max-time 15 "${auth[@]}" \
        -H "Title: $1" -H "Priority: $2" -H "Tags: $3" \
        --data-binary "$body" "$NTFY_URL" || echo "notify: curl failed" >> "$LOG"
}

{
    echo "### run started $(date '+%Y-%m-%d %H:%M:%S') host=$(hostname -s)"
    "$SCRIPT_DIR/weekly-maintenance.sh" --unattended
    echo "### exit $? at $(date '+%H:%M:%S')"
} >> "$LOG" 2>&1

# Decide whether a human needs to know
outdated=$(sed -n '/Outdated (/,/^🔍/p' "$LOG" | grep -E '^\s{5}\S' | tail -20)
infected=$(grep -oE 'Infected files: [0-9]+' "$LOG" | tail -1 | awk '{print $3}')
updates=$(grep -E '^\s*\* Label:' "$LOG" | tail -5)
errors=$(grep -iE 'freshclam update failed|FAIL|Error:' "$LOG" | tail -3)

summary=""
[ -n "$outdated" ] && summary+="Homebrew outdated:"$'\n'"$outdated"$'\n\n'
[ -n "$updates" ]  && summary+="macOS updates:"$'\n'"$updates"$'\n\n'
[ -n "$errors" ]   && summary+="Errors:"$'\n'"$errors"$'\n\n'

if [ -n "${infected:-}" ] && [ "$infected" != "0" ]; then
    printf '%s infected file(s) — see %s\n\n%s' "$infected" "$LOG" "$summary" \
        | notify "Weekly maintenance: MALWARE FOUND" urgent "biohazard,apple"
elif [ -n "$summary" ]; then
    printf '%s' "$summary" | notify "Weekly maintenance: action needed" default "apple,package"
fi
exit 0
