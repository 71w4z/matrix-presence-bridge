#!/bin/bash
# matrix-presence-bridge.sh v3 — System-Idle → Matrix Presence
# Nutzt /sync als Keepalive (Synapse braucht das für Presence!)

HOMESERVER="https://matrix.hoehn.de"
TOKEN_FILE="$HOME/.config/matrix-presence/token"
IDLE_THRESHOLD_MS=300000  # 5 Minuten
POLL_INTERVAL=30

# Token lesen
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "ERROR: Token not found: $TOKEN_FILE"
    exit 1
fi
TOKEN=$(cat "$TOKEN_FILE" | tr -d '[:space:]')

# User-ID ermitteln
WHOAMI=$(curl -sf -H "Authorization: Bearer $TOKEN" "$HOMESERVER/_matrix/client/v3/account/whoami")
if [[ $? -ne 0 ]]; then
    echo "ERROR: Auth failed. Check token."
    exit 1
fi
USER_ID=$(echo "$WHOAMI" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4)
USER_ID_ENC=$(echo "$USER_ID" | sed 's/@/%40/g; s/:/%3A/g')

echo "matrix-presence-bridge v3 started for $USER_ID (idle: $((IDLE_THRESHOLD_MS/1000))s, poll: ${POLL_INTERVAL}s)"

LAST_STATE=""
SINCE=""

while true; do
    # System-Idle auslesen
    IDLE_MS=0
    if command -v xprintidle &>/dev/null; then
        IDLE_MS=$(xprintidle 2>/dev/null || echo 0)
    elif command -v qdbus &>/dev/null; then
        IDLE_S=$(qdbus org.kde.screensaver /ScreenSaver GetSessionIdleTime 2>/dev/null || echo 0)
        IDLE_MS=$((IDLE_S * 1000))
    else
        echo "ERROR: xprintidle not found. Install: sudo zypper install xprintidle"
        sleep 60
        continue
    fi

    # Status bestimmen
    if [[ "$IDLE_MS" -ge "$IDLE_THRESHOLD_MS" ]]; then
        NEW_STATE="unavailable"
    else
        NEW_STATE="online"
    fi

    # /sync mit set_presence (DAS hält Synapse-Presence am Leben!)
    SYNC_URL="$HOMESERVER/_matrix/client/v3/sync?set_presence=${NEW_STATE}&timeout=0&filter={\"room\":{\"timeline\":{\"limit\":0}},\"presence\":{\"limit\":0}}"
    if [[ -n "$SINCE" ]]; then
        SYNC_URL="${SYNC_URL}&since=${SINCE}"
    fi
    SYNC_RESULT=$(curl -sf -H "Authorization: Bearer $TOKEN" "$SYNC_URL" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        NEW_SINCE=$(echo "$SYNC_RESULT" | grep -o '"next_batch":"[^"]*"' | cut -d'"' -f4)
        if [[ -n "$NEW_SINCE" ]]; then
            SINCE="$NEW_SINCE"
        fi

        if [[ "$NEW_STATE" != "$LAST_STATE" ]]; then
            echo "$(date '+%H:%M:%S') $LAST_STATE → $NEW_STATE (idle: $((IDLE_MS/1000))s)"
            LAST_STATE="$NEW_STATE"
        fi
    else
        echo "$(date '+%H:%M:%S') sync failed"
    fi

    sleep "$POLL_INTERVAL"
done
