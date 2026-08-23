#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root (for example: sudo $0)" >&2
  exit 1
fi

bridge_dir=/opt/meshmonitor-ble-bridge
bridge_repo=https://github.com/Yeraze/meshtastic-ble-bridge.git
bridge_commit=8604b2bdfe45f0d72a7ba2375763ba30dbf2c422
install -d "$bridge_dir"
if [[ ! -d "$bridge_dir/.git" ]]; then
  git clone "$bridge_repo" "$bridge_dir"
else
  git -C "$bridge_dir" fetch --depth 1 origin main
fi
git -C "$bridge_dir" checkout --detach "$bridge_commit"
python3 -m venv "$bridge_dir/.venv"
"$bridge_dir/.venv/bin/pip" install --upgrade pip
"$bridge_dir/.venv/bin/pip" install -r "$bridge_dir/src/requirements.txt"
chown -R meshmonitor:meshmonitor "$bridge_dir"
install -d -o root -g meshmonitor -m 0750 /etc/meshmonitor
if [[ ! -f /etc/meshmonitor/ble-bridge.env ]]; then
  install -o root -g meshmonitor -m 0640 /dev/null /etc/meshmonitor/ble-bridge.env
fi
systemctl daemon-reload
systemctl enable --now meshmonitor-ble-bridge.service
echo "BLE bridge installed at $bridge_dir (commit $bridge_commit)."
