# Native Linux installation (without Docker)

MeshMonitor can run directly as a Node.js service. From a fresh Debian or Ubuntu host, run `sudo scripts/install-native-linux.sh` from this checkout. The script installs Node.js 24 when needed, compiles the application, creates the unprivileged `meshmonitor` account, and installs a systemd unit at `/etc/systemd/system/meshmonitor.service`.

Set application values in `/etc/meshmonitor/meshmonitor.env`, especially `DATABASE_PATH`, `PORT`, `ALLOWED_ORIGINS`, and `SESSION_SECRET`. The default database location is `/var/lib/meshmonitor/data/meshmonitor.db`.

## Bluetooth (Meshtastic BLE)

The host needs a Bluetooth adapter and the Debian packages `bluetooth`, `bluez`, `dbus`, and (optionally) `avahi-daemon`. Pair and trust the radio with `bluetoothctl` first. MeshMonitor connects to the bridge's local TCP endpoint; it does not require Docker or privileged application access.

The companion bridge is maintained at `https://github.com/Yeraze/meshtastic-ble-bridge`. Install its Python requirements into `/opt/meshmonitor-ble-bridge/.venv`, copy the bridge source there, and configure `/etc/meshmonitor/ble-bridge.env` according to that bridge's documented options. This repository includes `scripts/systemd/meshmonitor-ble-bridge.service` so the bridge can run under the same unprivileged account. Enable it with:

```bash
sudo systemctl enable --now meshmonitor-ble-bridge.service
```

The bridge normally listens on TCP port 4403. Point a MeshMonitor Meshtastic source at `127.0.0.1:4403` (or the configured bridge address/port). Check logs with `journalctl -u meshmonitor-ble-bridge -f`.

The installer does not download or run Docker images, and it does not overwrite an existing environment file.
