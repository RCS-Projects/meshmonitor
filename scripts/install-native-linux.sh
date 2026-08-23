#!/usr/bin/env bash
set -euo pipefail

# Installs MeshMonitor and its optional native Meshtastic BLE bridge on Debian/Ubuntu.
# Run this script as root from the repository checkout; it does not use Docker.

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root (for example: sudo $0)" >&2
  exit 1
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
app_dir=/opt/meshmonitor
data_dir=/var/lib/meshmonitor
config_dir=/etc/meshmonitor
service_user=meshmonitor

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl git rsync build-essential python3 python3-venv python3-pip \
  bluetooth bluez dbus avahi-daemon avahi-utils

if ! command -v node >/dev/null || [[ "$(node -p 'parseInt(process.versions.node, 10)')" -lt 22 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi

getent group "$service_user" >/dev/null || groupadd --system "$service_user"
id -u "$service_user" >/dev/null 2>&1 || useradd --system --gid "$service_user" --home-dir "$data_dir" --shell /usr/sbin/nologin "$service_user"

install -d -o "$service_user" -g "$service_user" "$app_dir" "$data_dir/data" "$config_dir"
rsync -a --delete --exclude .git/ "$repo_dir/" "$app_dir/"
chown -R "$service_user:$service_user" "$app_dir" "$data_dir"

runuser -u "$service_user" -- npm ci --legacy-peer-deps --prefix "$app_dir"
runuser -u "$service_user" -- npm run build --prefix "$app_dir"
runuser -u "$service_user" -- npm run build:server --prefix "$app_dir"

if [[ ! -f "$config_dir/meshmonitor.env" ]]; then
  install -o root -g "$service_user" -m 0640 "$app_dir/.env.example" "$config_dir/meshmonitor.env"
  sed -i "s#^DATABASE_PATH=.*#DATABASE_PATH=$data_dir/data/meshmonitor.db#" "$config_dir/meshmonitor.env"
  sed -i 's/^NODE_ENV=.*/NODE_ENV=production/' "$config_dir/meshmonitor.env"
fi

install -o root -g root -m 0644 "$app_dir/scripts/systemd/meshmonitor.service" /etc/systemd/system/meshmonitor.service
install -o root -g root -m 0644 "$app_dir/scripts/systemd/meshmonitor-ble-bridge.service" /etc/systemd/system/meshmonitor-ble-bridge.service
systemctl daemon-reload
systemctl enable --now bluetooth.service meshmonitor.service
echo "MeshMonitor installed. Configure $config_dir/meshmonitor.env, then enable the BLE bridge if needed."
