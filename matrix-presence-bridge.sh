#!/bin/bash
# matrix-presence-bridge.sh v2 — System-Idle → Matrix Presence
# Keine python3-Abhängigkeit!

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
# URL-encode: @ → %40, : → %3A
USER_ID_ENC=$(echo "$USER_ID" | sed 's/@/%40/g; s/:/%3A/g')

echo "matrix-presence-bridge v2 started for $USER_ID (idle: $((IDLE_THRESHOLD_MS/1000))s, poll: ${POLL_INTERVAL}s)"

LAST_STATE=""
ERRORS=0

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

    # Nur bei Statuswechsel oder alle 5 Min refresh (keepalive)
    NOW=$(date +%s)
    FORCE_REFRESH=$(( (NOW % 300) < POLL_INTERVAL ? 1 : 0 ))

    if [[ "$NEW_STATE" != "$LAST_STATE" ]] || [[ "$FORCE_REFRESH" -eq 1 && "$ERRORS" -eq 0 ]]; then
        HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" -X PUT \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            "$HOMESERVER/_matrix/client/v3/presence/$USER_ID_ENC/status" \
            -d "{\"presence\": \"$NEW_STATE\"}")

        if [[ "$HTTP_CODE" == "200" ]]; then
            if [[ "$NEW_STATE" != "$LAST_STATE" ]]; then
                echo "$(date '+%H:%M:%S') $LAST_STATE → $NEW_STATE (idle: $((IDLE_MS/1000))s)"
            fi
            LAST_STATE="$NEW_STATE"
            ERRORS=0
        else
            ERRORS=$((ERRORS + 1))
            echo "$(date '+%H:%M:%S') ERROR: HTTP $HTTP_CODE (attempt $ERRORS)"
            if [[ "$ERRORS" -ge 10 ]]; then
                echo "Too many errors, sleeping 5 min..."
                sleep 300
                ERRORS=0
            fi
        fi
    fi

    sleep "$POLL_INTERVAL"
done
