#!/usr/bin/env sh
set -eu

: "${VAULT_DOMAIN:?export VAULT_DOMAIN first}"
: "${NOTES_DOMAIN:?export NOTES_DOMAIN first}"

check_url() {
  name="$1"
  url="$2"
  printf 'Checking %s: %s\n' "$name" "$url"
  curl --fail --silent --show-error --location --max-time 20 --output /dev/null "$url"
}

check_url Vaultwarden "https://${VAULT_DOMAIN}/alive"
check_url Joplin "https://${NOTES_DOMAIN}/api/ping"
printf 'Public HTTPS checks passed.\n'

