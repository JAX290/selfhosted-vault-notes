#!/bin/sh
set -eu
: "${SOURCE_DATA_DIR:?set SOURCE_DATA_DIR}"
: "${DEPLOY_DATA_DIR:?set DEPLOY_DATA_DIR}"
: "${BACKUP_DIR:?set BACKUP_DIR}"
old_container=${OLD_CONTAINER:-vaultwarden}
test "$SOURCE_DATA_DIR" != "$DEPLOY_DATA_DIR"
test -d "$SOURCE_DATA_DIR"
test ! -e "$DEPLOY_DATA_DIR/db.sqlite3"
mkdir -p "$DEPLOY_DATA_DIR" "$BACKUP_DIR"
old_image=$(docker inspect "$old_container" --format '{{.Image}}')
backup_name="vaultwarden-before-migration-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
docker stop "$old_container"
trap 'docker start "$old_container" >/dev/null 2>&1 || true' EXIT INT TERM
docker run --rm --entrypoint sh \
  -v "$SOURCE_DATA_DIR:/source:ro" \
  -v "$DEPLOY_DATA_DIR:/target" \
  -v "$BACKUP_DIR:/backup" \
  "$old_image" -ec \
  "tar -czf /backup/$backup_name -C /source . && cp -a /source/. /target/"
docker start "$old_container"
trap - EXIT INT TERM
printf 'Consistent backup and clone complete; original container restarted.\n'
