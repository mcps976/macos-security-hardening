#!/bin/bash
# weekly-maintenance-run.sh — launchd wrapper for weekly-maintenance.sh --unattended
#
# Keeps a dated log under ~/logs/weekly-maintenance/ and sends ONE notification
# per run: "action needed" when there is something for a person to do (outdated
# Homebrew packages, macOS updates available, an infected file, or a scan/update
# error), otherwise nothing: silence means healthy (the log keeps the results).
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
    # curl exits 0 on an HTTP error (no -f), so check the status: a dead token
    # (401) went unnoticed for days in October 2026.
    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "${auth[@]}" \
        -H "Title: $1" -H "Priority: $2" -H "Tags: $3" \
        --data-binary "$body" "$NTFY_URL") \
        || { echo "notify: curl failed (network)" >> "$LOG"; return 1; }
    [ "$code" = 200 ] || { echo "notify: ntfy returned HTTP $code — not delivered" >> "$LOG"; return 1; }
}

{
    echo "### run started $(date '+%Y-%m-%d %H:%M:%S') host=$(hostname -s)"
    "$SCRIPT_DIR/weekly-maintenance.sh" --unattended
    echo "### exit $? at $(date '+%H:%M:%S')"
    [ -x "$HOME/Git/macos/dotfiles-macos/scripts/check-ssh-config-drift.sh" ] && "$HOME/Git/macos/dotfiles-macos/scripts/check-ssh-config-drift.sh"
    # macOS updates recreate /etc/sudoers.d at 755 (27.2 did, 2026-10-30); 750 is the hardened mode.
    sudoers_mode=$(stat -f %Lp /etc/sudoers.d 2>/dev/null || echo missing)
    echo "sudoers.d mode: $sudoers_mode"
} >> "$LOG" 2>&1

# Decide whether a human needs to know
outdated=$(sed -n '/Outdated (/,/^🔍/p' "$LOG" | grep -E '^\s{5}\S' | tail -20)
infected=$(grep -oE 'Infected files: [0-9]+' "$LOG" | tail -1 | awk '{print $3}')
updates=$(grep -E '^\s*\* Label:' "$LOG" | tail -5)
errors=$(grep -iE 'freshclam update failed|FAIL|Error:' "$LOG" | tail -3)
sudoers=$(grep -E '^sudoers\.d mode: ' "$LOG" | tail -1 | grep -v ': 750$')

summary=""
[ -n "$outdated" ] && summary+="Homebrew outdated:"$'\n'"$outdated"$'\n\n'
[ -n "$updates" ]  && summary+="macOS updates:"$'\n'"$updates"$'\n\n'
[ -n "$errors" ]   && summary+="Errors:"$'\n'"$errors"$'\n\n'
[ -n "$sudoers" ]  && summary+="Permissions:"$'\n'"$sudoers (expected 750: sudo chmod 750 /etc/sudoers.d)"$'\n\n'

if [ -n "${infected:-}" ] && [ "$infected" != "0" ]; then
    printf '%s infected file(s) — see %s\n\n%s' "$infected" "$LOG" "$summary" \
        | notify "Weekly maintenance: MALWARE FOUND" urgent "biohazard,apple"
elif [ -n "$summary" ]; then
    printf '%s' "$summary" | notify "Weekly maintenance: action needed" default "apple,package"
fi
exit 0
