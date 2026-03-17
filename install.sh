#!/bin/bash
set -e

echo "=== Matrix Presence Bridge — Installer ==="

# 1. xprintidle
if ! command -v xprintidle &>/dev/null; then
    echo "Installiere xprintidle..."
    sudo zypper install -y xprintidle
fi

# 2. Token prüfen
if [[ -z "$1" ]]; then
    echo "Usage: ./install.sh <MATRIX_TOKEN>"
    echo "  Token bekommst du von Marc/Finn."
    exit 1
fi

# 3. Dateien installieren
mkdir -p ~/.local/bin ~/.config/matrix-presence ~/.config/systemd/user

cp matrix-presence-bridge.sh ~/.local/bin/
chmod +x ~/.local/bin/matrix-presence-bridge.sh

echo "$1" > ~/.config/matrix-presence/token
chmod 600 ~/.config/matrix-presence/token

cp matrix-presence-bridge.service ~/.config/systemd/user/

# 4. Service starten
systemctl --user daemon-reload
systemctl --user enable --now matrix-presence-bridge.service

echo ""
systemctl --user status matrix-presence-bridge.service --no-pager | head -5
echo ""
echo "✅ Fertig! Presence-Bridge läuft."
echo "   Rechner aktiv → 🟢  |  5 Min idle → 🟡  |  Rechner aus → ⚫"
