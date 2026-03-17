#!/bin/bash
# Einen User zur Presence Bridge hinzufügen
# Usage: ./add-user.sh USERNAME TOKEN
set -e

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 USERNAME TOKEN"
    exit 1
fi

USERNAME="$1"
TOKEN="$2"

# Config anlegen
mkdir -p /etc/matrix-presence-bridge
echo "TOKEN=$TOKEN" > "/etc/matrix-presence-bridge/${USERNAME}.conf"
chmod 600 "/etc/matrix-presence-bridge/${USERNAME}.conf"
chown "$USERNAME:" "/etc/matrix-presence-bridge/${USERNAME}.conf"

# Service aktivieren + starten
systemctl enable "matrix-presence-bridge@${USERNAME}.service"
systemctl restart "matrix-presence-bridge@${USERNAME}.service"

echo "✅ $USERNAME aktiviert"
systemctl status "matrix-presence-bridge@${USERNAME}.service" --no-pager | head -5
