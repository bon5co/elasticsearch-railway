# Elasticsearch 9.5.3 for Railway: one node, authenticated from boot, data on the volume.
FROM docker.elastic.co/elasticsearch/elasticsearch:9.5.3@sha256:f456578fc2a620a8a4f4c21d070fff1f6070345adb2be5e5626b65be72aea350

USER root

# Railway terminates TLS at its edge and speaks plain HTTP to the container, so the
# HTTP layer runs without TLS while authentication stays on. The settings live in
# elasticsearch.yml rather than ENV because the first-boot auto-configuration copies
# ENV settings into YAML unquoted, and `::` (dual-stack bind, needed for Railway's
# IPv6 private network) is not valid YAML bare. Transport stays on loopback.
COPY --chown=1000:0 elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml

# The anonymous user may call GET / (name and version) and nothing else, so Railway's
# unauthenticated healthcheck has something to hit without exposing cluster state.
COPY --chown=1000:0 roles.yml /usr/share/elasticsearch/config/roles.yml
COPY --chmod=0755 railway-entrypoint.sh /usr/local/bin/railway-entrypoint
COPY --chmod=0755 railway-password-sync.sh /usr/local/bin/railway-password-sync

ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/railway-entrypoint"]
CMD ["eswrapper"]
