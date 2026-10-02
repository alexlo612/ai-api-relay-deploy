# Current deployment evidence

## New API public hostname

**Observed:** 2026-10-02 08:24 UTC, on the deployment host as `alex`.
The infra Nginx route serves New API at
`https://newapi.byte612.com/api/status`: local origin and public Cloudflare
requests both returned HTTP 200. Public DNS for `api.byte612.com` now returns
NXDOMAIN, so infra removed the temporary old-host redirect and reissued the
certificate for newapi/sub2api only. Certificate and renewal checks are
recorded in the infra repo.

New API's persisted `ServerAddress` and `passkey.origins` were changed from
the old hostname to the new hostname in one PostgreSQL transaction. Passkey
login was disabled and `passkey_credentials` had zero rows before the change.
Only the `new-api` container was restarted to load the settings; it and the
other three Relay containers were healthy afterward. `/api/status` reports
`server_address=https://newapi.byte612.com` and
`passkey_rp_id=newapi.byte612.com`. The Relay Compose definition and ingress
network attachment did not change.

## Direct observation before the move

**Observed:** 2026-09-28 UTC, on `ubuntu-4gb-hel1-01` as `alex`.
**Scope:** local Docker state, checkout metadata, configured images, local origin
and public hostname requests. Secret values, application data, firewall rules,
and DNS provider settings were not read.

- The Relay project was running as `ai-api-relay` from
  `/home/alex/ai-api-relay-deploy/compose.yaml`. The checkout and remote `main`
  both pointed to `173db9a` (`Connect Relay backends to shared ingress`).
- Sub2API `0.1.138`, New API `v1.0.0-rc.40`, PostgreSQL `16.10-alpine`, Redis
  `7.4.5-alpine`, Certbot `v5.4.0`, and Relay Nginx `1.29.1-alpine` were
  configured. Sub2API, New API, PostgreSQL, and Redis were healthy; Relay
  Nginx was stopped. No Relay service was listening on host ports 3000/8080.
- Both apps were connected to `vps-infra_ingress`; only the apps joined that
  external network. The project also had private `backend` and `edge` networks.
- Compose volumes existed for both databases, Redis, both apps, logs, Certbot
  certificates, and the shared ACME webroot. The infra repo also referenced
  `ai-api-relay_acme_webroot`; that volume must remain intact.
- Local requests through infra Nginx returned HTTP 200 for
  `https://api.byte612.com/api/status` and
  `https://sub2api.byte612.com/health`. Requests to the same hostnames through
  the public Cloudflare path returned HTTP 403 with `cf-mitigated: challenge`.
  This shows the local origin routes were working; public client access still
  needs an external check.
- The old `.env` described IP mode and placeholder domains although infra
  routed `api.byte612.com` and `sub2api.byte612.com`. This made the old health
  script test the wrong endpoints. `/var/backups/vps-infra` did not yet exist.

## Migration and update result

**Completed:** 2026-09-28 14:50 UTC, on `ubuntu-4gb-hel1-01` as `alex`.

- Relay now runs from `/srv/stacks/ai-api-relay-deploy` with Compose project
  `ai-api-relay`. All four containers report healthy. The old checkout remains
  for reference, with its deployment `.env` removed. The only Relay containers
  have Compose working-directory labels for the new path. Rollback requires
  restoring the pre-upgrade backup and using the previous image tags.
- The protected `.env` is
  `/etc/vps-infra/secrets/ai-api-relay/.env`, mode `0600`; the new checkout's
  `.env` symlink resolves there. Secret-bearing settings were preserved while
  hostnames, backup location, and image tags were corrected.
- Upgraded and running tags: Sub2API `0.2.9`, PostgreSQL `16.15-alpine`, Redis
  `7.4.11-alpine`. New API remains `v1.0.0-rc.40` because the available stable
  tag is older and its database compatibility has not been reviewed.
- Pulled image digests:
  - `weishaw/sub2api:0.2.9` — `sha256:1f4a15d278fdedfa80188a0de538b81222bcc9a6bbe93bf91522c864737a90e3`
  - `calciumion/new-api:v1.0.0-rc.40` — `sha256:37c0f99a76ed0a5d5b376b8486173415efd1ec416042b392bd564eb0ae6a55ef`
  - `postgres:16.15-alpine` — `sha256:721873c34ceb9f8d8fc265984940dc982404c105f19ad51be9fdc5970a6080ea`
  - `redis:7.4.11-alpine` — `sha256:858f009f9709ce576febc734aa78b8f6d624b82571f9ddb6bda4377c833b3499`
- `sub2api` and `new-api` alone join `vps-infra_ingress`; PostgreSQL and Redis
  stay on `ai-api-relay_backend`. None of the four containers publishes a host
  port. Existing named volumes were reused: `ai-api-relay_postgres_data`,
  `ai-api-relay_redis_data`, `ai-api-relay_sub2api_data`,
  `ai-api-relay_new_api_data`, and `ai-api-relay_new_api_logs`.
- Pre-upgrade backup:
  `/home/alex/backups/ai-api-relay/backup-20260928-143700.tar.gz`;
  SHA-256 `acba72028955df1273e8997281cae133f510dacdf25ef795434308525e5452e4`.
  `sha256sum -c` passed; archive listing confirmed both PostgreSQL dumps and the
  Redis/application volume archive. The earlier pre-migration backup is also
  retained in the same directory.
- `nginx -t` passed for the infra Nginx container; it was gracefully reloaded
  after the app move so its Docker DNS entries resolved the recreated apps.
  Local HTTPS requests through that Nginx returned success for both app health
  paths. Both certificates expire `Dec 27 08:19:52 2026 GMT`.
- Those ingress checks were one-time cutover verification. Relay's ongoing
  `make health` now checks only Relay containers and internal app endpoints;
  ingress, Nginx, routes, and TLS checks belong to `vps-infra`.
- Public requests through Cloudflare previously returned HTTP 403 with
  `cf-mitigated: challenge`. External DNS, IPv4/IPv6 client access, and CDN
  behavior remain unverified.
- The first `make update` health check ran before the Sub2API Docker health
  state completed. A subsequent `make health` passed. Update and bootstrap now
  use Compose `--wait --wait-timeout 180` before running their full checks. A
  repeat `make update` then passed with all four services healthy. Its backup,
  `/home/alex/backups/ai-api-relay/backup-20260928-144938.tar.gz`, passed
  `sha256sum -c` with digest
  `0b235297777f84f2049fa7e69d0797f21a558b709d245101ec87c9ea917ea70e`.
- Validation tools installed for the `alex` account: ShellCheck 0.11.0,
  yamllint 1.37.1, and markdownlint-cli 0.49.1. Compose 5.2.0,
  `scripts/validate-env.sh`, ShellCheck, yamllint, markdownlint, `bash -n`,
  `git diff --check`, Redis authenticated `PING`, and a credential-pattern scan
  passed. Infra Nginx `nginx -t`, container health, and both local HTTPS routes
  also passed.
- Removed the obsolete Relay-owned Nginx/Certbot Compose services, their tracked
  templates and scripts, and unused generated Nginx/Redis configuration files.
- New API release review on 2026-09-28: GitHub marks `v1.0.0-rc.40` as the
  latest release; it is an RC. The most recent non-RC release found is `v0.13.2`
  from 2026-04-27. Recommendation: keep the already deployed RC.40 pinned and
  do not downgrade its database to v0.13.2 without a separate compatibility and
  restore rehearsal. See the official
  [release list](https://github.com/QuantumNous/new-api/releases),
  [v0.13.2 notes](https://github.com/QuantumNous/new-api/releases/tag/v0.13.2),
  and [RC.40 notes](https://github.com/QuantumNous/new-api/releases/tag/v1.0.0-rc.40).
