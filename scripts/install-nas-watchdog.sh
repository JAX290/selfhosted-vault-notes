#!/bin/sh
set -eu
base=/volume1/docker/vault-notes
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test -d "$base/nas"
command -v crontab >/dev/null
probe="$base/secrets/watchdog-crontab-probe"
mkdir -p "$base/secrets"
crontab -l > "$probe" 2>/dev/null || true
if ! crontab "$probe" 2>/dev/null; then
  rm -f "$probe"
  echo 'This NAS account cannot modify crontab. Run this installer from an administrator/root scheduled task.' >&2
  exit 1
fi
rm -f "$probe"
install -m 755 "$root_dir/scripts/watchdog-nas.sh" "$base/watchdog-nas.sh"
tmp="$base/secrets/watchdog-crontab.tmp"
crontab -l 2>/dev/null | grep -v 'watchdog-nas.sh' > "$tmp" || true
printf '*/2 * * * * %s >> %s 2>&1\n' "$base/watchdog-nas.sh" "$base/secrets/watchdog.log" >> "$tmp"
crontab "$tmp"
rm -f "$tmp"
"$base/watchdog-nas.sh"
echo 'NAS watchdog installed.'
crontab -l | grep 'watchdog-nas.sh'
