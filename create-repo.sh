#!/bin/bash
# Create complete GitHub repository structure

cd ~/Development/macos-security-hardening

# Create directories
mkdir -p scripts docs .github/workflows

# Copy existing scripts
cp ~/bin/mac-cleanup.sh scripts/ 2>/dev/null
cp ~/bin/clamscan-quick.sh scripts/ 2>/dev/null
cp ~/bin/mac-security-audit.sh scripts/ 2>/dev/null
cp ~/bin/weekly-maintenance.sh scripts/ 2>/dev/null
cp ~/bin/network-monitor.sh scripts/ 2>/dev/null
cp ~/fix-clamav.sh scripts/ 2>/dev/null

# Create README.md
cat > README.md << 'ENDREADME'
# macOS Security Hardening Stack

Open-source security and maintenance toolkit for macOS. Complete replacement for CleanMyMac.

## Features

- **LuLu** - Network firewall
- **OverSight** - Camera/mic monitor
- **BlockBlock** - Persistence monitor
- **ClamAV** - Malware scanner
- **Lynis** - Security auditor

## Quick Start
```bash
git clone https://github.com/YOUR_USERNAME/macos-security-hardening.git
cd macos-security-hardening
chmod +x install.sh
./install.sh
```

## Commands

- `cleanup` - System cleanup
- `scanmalware` - Malware scan
- `secaudit` - Security audit
- `netmon` - Network monitor

## License

MIT License - See LICENSE file
ENDREADME

# Create LICENSE
cat > LICENSE << 'ENDLICENSE'
MIT License

Copyright (c) 2025 Martin Swindells

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
ENDLICENSE

# Create .gitignore
cat > .gitignore << 'ENDGITIGNORE'
.DS_Store
*.log
logs/
tmp/
.vscode/
.idea/
ENDGITIGNORE

echo "✅ Repository structure created!"
echo "Next: git add . && git commit -m 'Initial commit'"
