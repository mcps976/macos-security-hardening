#!/bin/bash
# network-monitor.sh — topology-aware network posture check
#
# Your topology is read from a config file OUTSIDE this repo, so no real
# addresses are ever committed. Copy scripts/network.conf.example to
#   ~/.config/macos-security-hardening/network.conf
# and edit it. Override the location with NETWORK_MONITOR_CONF.
#
# Mullvad is assumed to be reached as a Tailscale exit node rather than via a
# local `mullvad` binary, so VPN state is read from Tailscale.

set -uo pipefail

CONF="${NETWORK_MONITOR_CONF:-$HOME/.config/macos-security-hardening/network.conf}"
HOSTS=(); ROUTE_TARGETS=(); INTERNAL_HOSTNAMES=()
if [ -r "$CONF" ]; then
    # shellcheck source=/dev/null
    . "$CONF"
else
    echo "note: no topology config at $CONF"
    echo "      copy scripts/network.conf.example there to enable subnet checks."
    echo
fi

TS=/usr/local/bin/tailscale
[ -x "$TS" ] || TS=$(command -v tailscale 2>/dev/null)
HAVE_JQ=$(command -v jq >/dev/null 2>&1 && echo yes || echo no)

echo "=== Network Monitor — $(date '+%Y-%m-%d %H:%M') ==="
echo

# ------------------------------------------------------------------
echo "--- Local position ---"
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "not on en0")
echo "  en0 address : $LOCAL_IP"
route -n get default 2>/dev/null | awk '/interface:/{print "  default via : "$2} /gateway:/{print "  gateway     : "$2}'
echo

# ------------------------------------------------------------------
echo "--- Path to each homelab subnet (tunnel vs wire) ---"
for target in "${ROUTE_TARGETS[@]}"; do
    IFACE=$(route -n get "$target" 2>/dev/null | awk '/interface:/{print $2}')
    printf '  %-15s -> %s\n' "$target" "${IFACE:-no route}"
done
[ ${#ROUTE_TARGETS[@]} -eq 0 ] && echo "  (none configured)"
echo "  (utunN = via Tailscale subnet route, en0 = direct on the wire)"
echo

# ------------------------------------------------------------------
echo "--- Homelab reachability (TCP probe) ---"
# TCP, not ICMP: many firewalls drop pings while serving happily, so a ping test
# reports the gateway as down while it is happily serving on that port.
for entry in "${HOSTS[@]}"; do
    # shellcheck disable=SC2086  # deliberate word-split of the config line
    set -- $entry
    ip="$1"; port="$2"; shift 2; label="$*"
    if nc -z -G 2 -w 2 "$ip" "$port" >/dev/null 2>&1; then
        printf '  ✓ %-15s :%-5s %s\n' "$ip" "$port" "$label"
    else
        printf '  ✗ %-15s :%-5s %s (no TCP response)\n' "$ip" "$port" "$label"
    fi
done
echo

# ------------------------------------------------------------------
echo "--- Tailscale ---"
if [ -n "${TS:-}" ] && [ -x "$TS" ]; then
    if [ "$HAVE_JQ" = yes ]; then
        "$TS" status --json 2>/dev/null | jq -r '
          "  backend     : \(.BackendState)",
          "  this node   : \(.Self.DNSName | rtrimstr(".")) (\(.Self.TailscaleIPs[0]))",
          "  tags        : \(.Self.Tags // ["none"] | join(", "))",
          "  exit node   : \([.Peer[] | select(.ExitNode) | .HostName] | if length>0 then .[0] else "none" end)",
          "  mullvad avl : \([.Peer[] | select(.DNSName | test("mullvad"))] | length) exit nodes offered"'
        echo -n "  subnet rts  : "
        "$TS" status --json 2>/dev/null | jq -rc '[.Peer[] | select(.PrimaryRoutes) | .PrimaryRoutes[]] | if length>0 then join(", ") else "none received" end'
    else
        "$TS" status 2>/dev/null | head -10
    fi
else
    echo "  Tailscale CLI not found"
fi
echo

# ------------------------------------------------------------------
echo "--- Actual egress ---"
EGRESS=$(curl -m 8 -s https://api.ipify.org 2>/dev/null)
echo "  public IP   : ${EGRESS:-unreachable}"
echo "  (differs from your ISP address when a Mullvad exit node is active)"
echo

# ------------------------------------------------------------------
echo "--- DNS ---"
echo "  resolvers:"
scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print "    "$3}' | sort -u
echo "  internal hostname resolution:"
for h in "${INTERNAL_HOSTNAMES[@]}"; do
    RESOLVED=$(dscacheutil -q host -a name "$h" 2>/dev/null | awk '/^ip_address:/{print $2; exit}')
    printf '    %-20s -> %s\n' "$h" "${RESOLVED:-FAILED}"
done
echo

# ------------------------------------------------------------------
echo "--- Established connections (top 20 by remote host) ---"
# macOS netstat separates the port with '.', not ':' — the original `cut -d: -f1`
# left the port attached on IPv4 and mangled IPv6 addresses.
netstat -an 2>/dev/null | awk '/ESTABLISHED/{print $5}' \
    | sed 's/\.[0-9][0-9]*$//' \
    | sort | uniq -c | sort -rn | head -20
echo

echo "--- Listening services ---"
echo "  Address                Process"
sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | awk 'NR>1 {printf "  %-22s %s\n", $9, $1}' | sort -u
echo
