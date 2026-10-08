#!/bin/sh
set -eu
test "$(id -u)" -eq 0 || { echo 'Run as root'; exit 1; }
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test -f /opt/vault-notes/edge.env
test -f /etc/systemd/system/vault-notes-edge.service
install -d -m 755 /opt/vault-notes /var/lib/vault-notes-watchdog
install -m 755 "$root_dir/scripts/watchdog-vps.sh" /opt/vault-notes/watchdog-vps.sh
install -m 644 "$root_dir/vps/vault-notes-watchdog.service" /etc/systemd/system/vault-notes-watchdog.service
install -m 644 "$root_dir/vps/vault-notes-watchdog.timer" /etc/systemd/system/vault-notes-watchdog.timer
systemctl daemon-reload
systemctl enable --now vault-notes-watchdog.timer
systemctl start vault-notes-watchdog.service
echo 'VPS watchdog installed.'
systemctl list-timers vault-notes-watchdog.timer --no-pager
