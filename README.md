# elasticsearch-railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/elasticsearch-or-just-updated-v9-search-?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Deploy on Railway:** [Elasticsearch template](https://railway.com/deploy/elasticsearch-or-just-updated-v9-search-?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

Elasticsearch 9.5.3, single node, wrapped so it deploys cleanly on [Railway](https://railway.com)
with authentication on from the first boot and its data on a Railway volume.

What the wrapper changes against the stock `docker.elastic.co/elasticsearch/elasticsearch` image:

1. **Railway mounts volumes owned by root; Elasticsearch runs as uid 1000.** The entrypoint
   repairs ownership of `/usr/share/elasticsearch/data` as root, then hands the process to
   uid 1000 with `chroot --userspec` (the image ships no gosu or setpriv).
2. **Railway terminates TLS at its edge.** HTTP-layer TLS is off, authentication stays on, and
   the first-boot security auto-configuration (which would turn TLS on) never runs.
3. **Nothing but `GET /` answers without credentials.** An anonymous role limited to
   `cluster:monitor/main` gives Railway's healthcheck a 200; `_cluster/state`, `_cat/*`,
   `_nodes` and every index return 401.
4. **`$PORT` is honoured** (`http.port`), and HTTP binds `::`, so the node is reachable over
   Railway's IPv6 private network as well as its public domain.
5. **mmap stays on** when the host's `vm.max_map_count` allows it (Railway's does).
6. **The heap is left to Elasticsearch,** which sizes it from the container's memory limit.
7. **An empty `ELASTIC_PASSWORD` refuses to boot**, and the variable stays authoritative: if
   the `elastic` password was changed through the API, the next boot sets it back to the
   variable, so a redeploy is a working password reset.

## Variables

| Variable | Purpose |
| --- | --- |
| `ELASTIC_PASSWORD` | **Required.** Password of the `elastic` superuser, at least 6 characters. |
| `PORT` | Injected by Railway. Defaults to `9200`. |

Mount a volume at `/usr/share/elasticsearch/data`.

Image: `ghcr.io/bon5co/elasticsearch-railway:9.5.3`, built by GitHub Actions from this repository.
