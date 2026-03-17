#!/bin/bash
# matrix-presence-bridge.sh — System-Idle → Matrix Presence
# Läuft als systemd user service auf MA-Rechnern (openSUSE/KDE)
# Meldet System-Idle (Maus+Tastatur) direkt an Synapse

HOMESERVER="https://matrix.hoehn.de"
TOKEN_FILE="$HOME/.config/matrix-presence/token"
IDLE_THRESHOLD_MS=300000  # 5 Minuten in ms
POLL_INTERVAL=30          # Alle 30 Sekunden prüfen

# Token lesen
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "ERROR: Token file not found: $TOKEN_FILE"
    echo "Run: mkdir -p ~/.config/matrix-presence && echo 'YOUR_TOKEN' > $TOKEN_FILE"
    exit 1
fi
TOKEN=$(cat "$TOKEN_FILE")

# User-ID ermitteln
USER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$HOMESERVER/_matrix/client/v3/account/whoami" | \
    python3 -c "import json,sys; print(json.load(sys.stdin)['user_id'])" 2>/dev/null)

if [[ -z "$USER_ID" || "$USER_ID" == "None" ]]; then
    echo "ERROR: Could not authenticate. Check token."
    exit 1
fi

echo "matrix-presence-bridge started for $USER_ID (idle threshold: $((IDLE_THRESHOLD_MS/1000))s)"

LAST_STATE=""

while true; do
    # System-Idle auslesen (ms seit letztem Input)
    # xprintidle für X11/KDE, qdbus für Wayland/KDE
    if command -v xprintidle &>/dev/null; then
        IDLE_MS=$(xprintidle 2>/dev/null || echo 0)
    elif command -v qdbus &>/dev/null; then
        IDLE_MS=$(qdbus org.kde.screensaver /ScreenSaver GetSessionIdleTime 2>/dev/null || echo 0)
        IDLE_MS=$((IDLE_MS * 1000))  # qdbus gibt Sekunden zurück
    else
        echo "ERROR: Neither xprintidle nor qdbus found. Install: sudo zypper install xprintidle"
        exit 1
    fi

    # Status bestimmen
    if [[ "$IDLE_MS" -ge "$IDLE_THRESHOLD_MS" ]]; then
        NEW_STATE="unavailable"
    else
        NEW_STATE="online"
    fi

    # Nur bei Statuswechsel an Synapse melden (spart API-Calls)
    if [[ "$NEW_STATE" != "$LAST_STATE" ]]; then
        curl -s -X PUT \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            "$HOMESERVER/_matrix/client/v3/presence/$( python3 -c "import urllib.parse; print(urllib.parse.quote('$USER_ID'))" )/status" \
            -d "{\"presence\": \"$NEW_STATE\"}" >/dev/null 2>&1
        echo "$(date '+%H:%M:%S') $USER_ID: $LAST_STATE → $NEW_STATE (idle: $((IDLE_MS/1000))s)"
        LAST_STATE="$NEW_STATE"
    fi

    sleep "$POLL_INTERVAL"
done
