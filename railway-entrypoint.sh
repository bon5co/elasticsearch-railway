#!/usr/bin/env bash
# Runs as root: repair the root-owned Railway volume, pick settings from what the
# container actually has, then hand over to the stock entrypoint as uid 1000
# (Elasticsearch refuses to run as root; the image ships chroot but no gosu/setpriv).
set -euo pipefail

ES_HOME=/usr/share/elasticsearch
DATA_DIR="$ES_HOME/data"

if [ -z "${ELASTIC_PASSWORD:-}" ]; then
  echo "[railway] FATAL: ELASTIC_PASSWORD is empty. Refusing to start Elasticsearch on a public URL without a password." >&2
  exit 1
fi
if [ "${#ELASTIC_PASSWORD}" -lt 6 ]; then
  echo "[railway] FATAL: ELASTIC_PASSWORD must be at least 6 characters (Elasticsearch's own minimum)." >&2
  exit 1
fi

mkdir -p "$DATA_DIR" "$ES_HOME/logs"
owner="$(stat -c %u:%g "$DATA_DIR")"
if [ "$owner" != "1000:0" ]; then
  echo "[railway] data volume owned by $owner, repairing to 1000:0"
  chown -R 1000:0 "$DATA_DIR"
fi
chown -R 1000:0 "$ES_HOME/logs"

PORT="${PORT:-9200}"

# mmap is Elasticsearch's fast path for index files (and for HNSW vectors). It needs
# vm.max_map_count >= 262144; only fall back to niofs when the host is really below it.
MAP_COUNT="$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)"
if [ "$MAP_COUNT" -ge 262144 ]; then
  ALLOW_MMAP=true
else
  ALLOW_MMAP=false
fi
echo "[railway] port=$PORT vm.max_map_count=$MAP_COUNT allow_mmap=$ALLOW_MMAP data_owner=$(stat -c %u:%g "$DATA_DIR")"

# ELASTIC_PASSWORD only bootstraps the elastic user on the very first boot. The sync
# helper makes a changed variable take effect on the next redeploy.
chroot --userspec=1000:0 --groups=0 --skip-chdir / \
  env HOME="$ES_HOME" PORT="$PORT" /usr/local/bin/railway-password-sync &

exec chroot --userspec=1000:0 --groups=0 --skip-chdir / \
  env HOME="$ES_HOME" "http.port=$PORT" "node.store.allow_mmap=$ALLOW_MMAP" \
  /usr/local/bin/docker-entrypoint.sh "$@"
