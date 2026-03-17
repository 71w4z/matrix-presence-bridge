#!/bin/bash
# matrix-presence-bridge.sh v5 — System-Idle → Matrix Presence
# Läuft als System-Service, findet X11-Session automatisch

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

echo "matrix-presence-bridge v5 started for $USER_ID (idle: $((IDLE_THRESHOLD_MS/1000))s, poll: ${POLL_INTERVAL}s)"

LAST_STATE=""
SINCE=""

# X11 Display + Xauthority finden (openSUSE/KDE: Xauthority in /tmp/)
find_x11() {
    # Aus der Desktop-Session (plasmashell, kwin, Xorg) die Env-Vars holen
    for proc in plasmashell kwin_x11 Xorg; do
        PID=$(pgrep -u "$USER" "$proc" 2>/dev/null | head -1)
        if [[ -n "$PID" ]]; then
            FOUND_DISPLAY=$(cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep '^DISPLAY=' | cut -d= -f2)
            FOUND_XAUTH=$(cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep '^XAUTHORITY=' | cut -d= -f2)
            if [[ -n "$FOUND_DISPLAY" && -n "$FOUND_XAUTH" && -f "$FOUND_XAUTH" ]]; then
                export DISPLAY="$FOUND_DISPLAY"
                export XAUTHORITY="$FOUND_XAUTH"
                return 0
            fi
        fi
    done
    return 1
}

while true; do
    # X11 finden (jede Runde, falls Session sich ändert)
    if ! find_x11; then
        # Kein Desktop → User nicht eingeloggt → unavailable
        IDLE_MS=999999999
    elif command -v xprintidle &>/dev/null; then
        IDLE_MS=$(xprintidle 2>/dev/null || echo 999999999)
    else
        IDLE_MS=999999999
    fi

    if [[ "$IDLE_MS" -ge "$IDLE_THRESHOLD_MS" ]]; then
        NEW_STATE="unavailable"
    else
        NEW_STATE="online"
    fi

    # /sync mit set_presence
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
            echo "$(date '+%H:%M:%S') $LAST_STATE → $NEW_STATE (idle: $((IDLE_MS/1000))s, display=$DISPLAY)"
            LAST_STATE="$NEW_STATE"
        fi
    else
        echo "$(date '+%H:%M:%S') sync failed"
    fi

    sleep "$POLL_INTERVAL"
done
