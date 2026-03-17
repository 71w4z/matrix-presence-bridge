# Matrix Presence Bridge

Zeigt den Online-Status in Element basierend auf der **Rechner-Aktivität** (Maus/Tastatur).

| Zustand | Element zeigt |
|---------|--------------|
| Rechner aktiv | 🟢 Online |
| 5 Min keine Maus/Tastatur | 🟡 Abwesend |
| Rechner aus / Service gestoppt | ⚫ Offline |

## Installation

```bash
git clone https://github.com/71w4z/matrix-presence-bridge.git
cd matrix-presence-bridge
./install.sh DEIN_TOKEN
```

Token bekommst du von Marc oder Finn.

## Voraussetzung

- openSUSE / KDE (oder jedes Linux mit X11)
- `xprintidle` (wird automatisch installiert)

## Update

```bash
cd matrix-presence-bridge
git pull
cp matrix-presence-bridge.sh ~/.local/bin/
systemctl --user restart matrix-presence-bridge.service
```

## Deinstallieren

```bash
systemctl --user disable --now matrix-presence-bridge.service
rm ~/.local/bin/matrix-presence-bridge.sh
rm ~/.config/systemd/user/matrix-presence-bridge.service
rm -rf ~/.config/matrix-presence
```

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| `xprintidle: not found` | `sudo zypper install xprintidle` |
| `Could not authenticate` | Token prüfen: `cat ~/.config/matrix-presence/token` |
| Service startet nicht nach Reboot | `loginctl enable-linger $USER` |
| Status prüfen | `systemctl --user status matrix-presence-bridge` |
| Logs | `journalctl --user -u matrix-presence-bridge -f` |
