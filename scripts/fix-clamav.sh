#!/bin/bash
# Fix ClamAV Configuration

echo "=== Configuring ClamAV ==="
echo

# Config, database and logs stay under Homebrew's prefix; the binaries come from
# Cisco's package (Cisco-Talos/clamav#1887, PR #1873). Revert CLAMAV_BIN to
# /opt/homebrew/bin once Homebrew ships a fixed clamav.
CLAMAV_BIN="/usr/local/clamav/bin"
CLAMAV_CONF="/opt/homebrew/etc/clamav/freshclam.conf"

# Create config directory if it doesn't exist
sudo mkdir -p /opt/homebrew/etc/clamav

# Copy example configs and remove the 'Example' line
echo "Creating freshclam.conf..."
sudo cp /opt/homebrew/etc/clamav/freshclam.conf.sample /opt/homebrew/etc/clamav/freshclam.conf 2>/dev/null || \
sudo sh -c 'echo "DatabaseDirectory /opt/homebrew/var/lib/clamav
UpdateLogFile /opt/homebrew/var/log/clamav/freshclam.log
DatabaseMirror database.clamav.net" > /opt/homebrew/etc/clamav/freshclam.conf'

# Remove the Example line (required)
sudo sed -i '' '/^Example/d' /opt/homebrew/etc/clamav/freshclam.conf

# The sample ships with UpdateLogFile commented out, and the `cp` above
# normally succeeds — so the fallback heredoc that sets it never runs. Without
# a log, a failing freshclam is invisible (clamscan-quick.sh swallows the
# error and scans with stale definitions). Ensure each directive is present.
ensure_directive() {
    local file="$1" key="$2" value="$3"
    if ! grep -qE "^${key}\b" "$file"; then
        sudo sh -c "echo '${key} ${value}' >> '$file'"
    fi
}
ensure_directive /opt/homebrew/etc/clamav/freshclam.conf DatabaseDirectory /opt/homebrew/var/lib/clamav
ensure_directive /opt/homebrew/etc/clamav/freshclam.conf UpdateLogFile /opt/homebrew/var/log/clamav/freshclam.log
ensure_directive /opt/homebrew/etc/clamav/freshclam.conf LogTime yes

echo "Creating clamd.conf..."
sudo cp /opt/homebrew/etc/clamav/clamd.conf.sample /opt/homebrew/etc/clamav/clamd.conf 2>/dev/null || \
sudo sh -c 'echo "LogFile /opt/homebrew/var/log/clamav/clamd.log
PidFile /opt/homebrew/var/run/clamav/clamd.pid
DatabaseDirectory /opt/homebrew/var/lib/clamav" > /opt/homebrew/etc/clamav/clamd.conf'

# Remove the Example line
sudo sed -i '' '/^Example/d' /opt/homebrew/etc/clamav/clamd.conf

# Create necessary directories
sudo mkdir -p /opt/homebrew/var/lib/clamav
sudo mkdir -p /opt/homebrew/var/log/clamav
sudo mkdir -p /opt/homebrew/var/run/clamav

# Set permissions
sudo chown -R $(whoami) /opt/homebrew/var/lib/clamav
sudo chown -R $(whoami) /opt/homebrew/var/log/clamav
sudo chown -R $(whoami) /opt/homebrew/var/run/clamav

echo "✓ ClamAV configured"
echo

# Update virus definitions
echo "Updating ClamAV virus definitions..."
"$CLAMAV_BIN/freshclam" --config-file="$CLAMAV_CONF"

echo
echo "✓ ClamAV setup complete"
echo

