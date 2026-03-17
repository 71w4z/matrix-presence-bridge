#!/bin/bash
# matrix-presence-bridge.sh v4 — System-Idle → Matrix Presence
# Läuft als System-Service, braucht keine User-Session

HOMESERVER="https://matrix.hoehn.de"
IDLE_THRESHOLD_MS=420000  # 7 Minuten
POLL_INTERVAL=30

# Config: /etc/matrix-presence-bridge/$USER.conf
CONF="/etc/matrix-presence-bridge/${USER}.conf"
if [[ ! -f "$CONF" ]]; then
    echo "ERROR: Config not found: $CONF"
    exit 1
fi
source "$CONF"
# CONF muss TOKEN= enthalten

if [[ -z "$TOKEN" ]]; then
    echo "ERROR: TOKEN not set in $CONF"
    exit 1
fi

# User-ID ermitteln
WHOAMI=$(curl -sf -H "Authorization: Bearer $TOKEN" "$HOMESERVER/_matrix/client/v3/account/whoami")
if [[ $? -ne 0 ]]; then
    echo "ERROR: Auth failed. Check TOKEN in $CONF"
    exit 1
fi
USER_ID=$(echo "$WHOAMI" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4)

echo "matrix-presence-bridge v4 started for $USER_ID (idle: $((IDLE_THRESHOLD_MS/1000))s, poll: ${POLL_INTERVAL}s)"

LAST_STATE=""
SINCE=""

while true; do
    # System-Idle: DISPLAY muss gesetzt sein für xprintidle
    IDLE_MS=0
    if [[ -n "$DISPLAY" ]] && command -v xprintidle &>/dev/null; then
        IDLE_MS=$(xprintidle 2>/dev/null || echo 999999999)
    elif command -v qdbus &>/dev/null; then
        IDLE_S=$(qdbus org.kde.screensaver /ScreenSaver GetSessionIdleTime 2>/dev/null || echo 99999)
        IDLE_MS=$((IDLE_S * 1000))
    else
        # Kein X11 Zugriff → User nicht am Desktop → unavailable
        IDLE_MS=999999999
    fi

    if [[ "$IDLE_MS" -ge "$IDLE_THRESHOLD_MS" ]]; then
        NEW_STATE="unavailable"
    else
        NEW_STATE="online"
    fi

    # /sync mit set_presence (hält Synapse-Presence am Leben)
    SYNC_URL="${HOMESERVER}/_matrix/client/v3/sync?set_presence=${NEW_STATE}&timeout=0"
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
