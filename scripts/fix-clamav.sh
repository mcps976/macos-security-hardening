#!/bin/bash
# Fix ClamAV Configuration

echo "=== Configuring ClamAV ==="
echo

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
freshclam

echo
echo "✓ ClamAV setup complete"
echo

