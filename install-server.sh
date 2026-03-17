#!/bin/bash
# Matrix Presence Bridge — Server-Install (als root ausführen!)
set -e

echo "=== Matrix Presence Bridge — Server-Install ==="

# 1. xprintidle
if ! command -v xprintidle &>/dev/null; then
    echo "Installiere xprintidle..."
    zypper install -y xprintidle 2>/dev/null || apt install -y xprintidle 2>/dev/null
fi

# 2. Script installieren
mkdir -p /opt/matrix-presence-bridge
cp matrix-presence-bridge.sh /opt/matrix-presence-bridge/
chmod +x /opt/matrix-presence-bridge/matrix-presence-bridge.sh

# 3. Service-Template installieren
cp matrix-presence-bridge@.service /etc/systemd/system/
systemctl daemon-reload

echo "✅ Basis installiert."
echo ""
echo "Jetzt pro User aktivieren:"
echo "  ./add-user.sh paul TOKEN"
echo "  ./add-user.sh sebastian TOKEN"
echo "  etc."
