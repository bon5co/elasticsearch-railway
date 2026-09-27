#!/usr/bin/env bash
# Make ELASTIC_PASSWORD authoritative on every boot, not only the first.
# Upstream reads it once, as the keystore's bootstrap.password, and ignores it once the
# elastic user has a password in the .security index, so changing the variable later
# silently does nothing. When the variable no longer authenticates, a throwaway
# file-realm superuser (config/users lives on the image layer, not the volume) sets
# it through the security API and is removed again.
set -uo pipefail
cd /usr/share/elasticsearch

URL="http://127.0.0.1:${PORT:-9200}"
auth_code() { curl -s -o /dev/null -w '%{http_code}' -u "$1:$2" "$URL/_security/_authenticate"; }

code=000
for _ in $(seq 1 300); do
  code="$(auth_code elastic "$ELASTIC_PASSWORD")"
  case "$code" in 200|401) break ;; esac
  sleep 2
done

case "$code" in
  200) echo "[railway] elastic password matches ELASTIC_PASSWORD"; exit 0 ;;
  401) echo "[railway] ELASTIC_PASSWORD changed since the last boot, applying it" ;;
  *) echo "[railway] WARNING: Elasticsearch did not answer within 10 minutes (last HTTP $code); password not checked" >&2; exit 0 ;;
esac

tmp_user="railway_reset_$(date +%s)"
tmp_pass="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)"
bin/elasticsearch-users useradd "$tmp_user" -p "$tmp_pass" -r superuser >/dev/null
for _ in $(seq 1 60); do
  [ "$(auth_code "$tmp_user" "$tmp_pass")" = 200 ] && break
  sleep 1
done

esc="$(printf '%s' "$ELASTIC_PASSWORD" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
result="$(curl -s -o /dev/null -w '%{http_code}' -u "$tmp_user:$tmp_pass" \
  -H 'Content-Type: application/json' -X POST "$URL/_security/user/elastic/_password" \
  -d "{\"password\":\"$esc\"}")"
bin/elasticsearch-users userdel "$tmp_user" >/dev/null

if [ "$result" = 200 ] && [ "$(auth_code elastic "$ELASTIC_PASSWORD")" = 200 ]; then
  echo "[railway] elastic password reset to ELASTIC_PASSWORD"
else
  echo "[railway] ERROR: could not apply ELASTIC_PASSWORD (HTTP $result)" >&2
fi
