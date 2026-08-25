#!/bin/sh
set -eu

REPO=/opt/meshmonitor

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root." >&2
  exit 1
fi

git -C "$REPO" fetch origin main
git -C "$REPO" checkout --detach origin/main
git -C "$REPO" submodule update --init --recursive

chown -R meshmonitor:meshmonitor "$REPO"
sudo -u meshmonitor npm --prefix "$REPO" ci --legacy-peer-deps
sudo -u meshmonitor npm --prefix "$REPO" run build
sudo -u meshmonitor npm --prefix "$REPO" run build:server

systemctl restart meshmonitor.service
systemctl --no-pager --full status meshmonitor.service
