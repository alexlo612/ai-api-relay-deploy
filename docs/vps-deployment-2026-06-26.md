# VPS deployment note — 2026-06-26

Target: `alex@89.167.21.176`

## Preflight

- OS: Ubuntu 24.04.4 LTS, x86_64
- Kernel: Linux 6.8.0-124-generic
- RAM: 3.7 GiB
- Swap: 2 GiB `/swapfile`
- Disk: 38 GiB root filesystem, about 22 GiB free before deployment
- Docker: 29.6.0
- Docker Compose: v5.2.0
- User: `alex`, member of `docker` group after manual `sudo usermod -aG docker alex`
- Deployment directory: `/home/alex/ai-api-relay-deploy`

## Image tags deployed

- PostgreSQL: `postgres:16.10-alpine`
- Redis: `redis:7.4.5-alpine`
- Nginx: `nginx:1.29.1-alpine`
- Certbot: `certbot/certbot:v5.4.0`
- Sub2API: `weishaw/sub2api:0.1.138`
- New API: `calciumion/new-api:v1.0.0-rc.15`

## Validation summary

- `docker compose config` succeeded on the VPS.
- PostgreSQL, Redis, Sub2API, New API, and Nginx were healthy.
- Public HTTPS endpoints succeeded:
  - `https://89.167.21.176:8080/health`
  - `https://89.167.21.176:3000/api/status`
- Production Let's Encrypt IP certificate issued for `89.167.21.176`.
- PostgreSQL and Redis were not published on host ports.
- Redis unauthenticated access returned `NOAUTH Authentication required`.
- Sub2API PostgreSQL user could connect to `sub2api` database and was denied access to `newapi` database.
- Named volumes were created for PostgreSQL, Redis, Sub2API, New API data/logs, Let's Encrypt, and ACME webroot.
- Local backup completed and checksum verified.
- Sub2API and New API restarted and returned healthy after recreation.

## Non-secret notes

- `.env` exists only on the VPS and is mode `0600`.
- The GitHub deploy key added to the repository is read-only.
- Nginx reports deprecation warnings for `listen ... http2`; config test still succeeds. This can be cleaned up later by switching to the newer `http2 on;` syntax.
