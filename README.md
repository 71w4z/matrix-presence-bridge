# Matrix Presence Bridge

System-Idle → Matrix Presence (Synapse). Zeigt ob jemand am Rechner sitzt.

| Zustand | Element zeigt |
|---------|--------------|
| Rechner aktiv | 🟢 Online |
| 7 Min idle | ⭕ Abwesend |
| Rechner aus | ⚫ Offline |

## Installation (als root)

```bash
git clone https://github.com/71w4z/matrix-presence-bridge.git
cd matrix-presence-bridge
./install-server.sh
```

## User hinzufügen

```bash
./add-user.sh paul TOKEN
./add-user.sh sebastian TOKEN
./add-user.sh agron TOKEN
```

## Status prüfen

```bash
systemctl status matrix-presence-bridge@paul
journalctl -u matrix-presence-bridge@paul -f
```

## Update

```bash
cd matrix-presence-bridge
git pull
cp matrix-presence-bridge.sh /opt/matrix-presence-bridge/
systemctl restart matrix-presence-bridge@paul matrix-presence-bridge@sebastian matrix-presence-bridge@agron
```

## User entfernen

```bash
systemctl disable --now matrix-presence-bridge@USERNAME
rm /etc/matrix-presence-bridge/USERNAME.conf
```
