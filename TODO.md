# Implementation TODO

This checklist is ordered so an agent can complete it from top to bottom. An item may be checked only after its acceptance checks pass.

Status note, 2026-06-25: local repository implementation is complete for sections 0–14. Runtime acceptance items that require Docker, Nginx containers, live certificates, or the VPS remain unchecked until those environments are available or explicitly authorized. Sections 15–17 remain unchecked because they require explicit VPS/GitHub authorization.

## 0. Repository foundation

- [x] Review `PRD.md`, `USER_GUIDE.md`, and `AGENTS.md`; record any contradictions before coding.
- [x] Confirm the upstream Sub2API and New API image names, current stable tags, supported environment variables, health endpoints, database requirements, and Redis connection formats from official sources.
- [x] Create the planned repository structure: `config/`, `postgres/init/`, `scripts/`, `backups/`, and `.github/workflows/`.
- [x] Add `backups/.gitkeep`.
- [x] Extend `.gitignore` if implementation introduces additional runtime files.
- [x] Add an MIT or other user-approved license before publishing to GitHub.
- [x] Ensure `README.md` links to the PRD, user guide, and this checklist.

Acceptance:

- [x] `git status` contains no generated secrets, runtime data, certificates, logs, or database files.
- [x] Documentation consistently describes IP-first deployment and future domain migration.

## 1. Environment contract

- [x] Create a fully documented `.env.example`.
- [x] Add `DEPLOYMENT_MODE=ip|domain`, `SERVER_PUBLIC_IP=89.167.21.176`, timezone, Compose project name, image tags, resource limits, log rotation, and backup retention settings.
- [x] Add separate PostgreSQL database names, users, and passwords for Sub2API and New API.
- [x] Add Redis password and separate DB indexes.
- [x] Add Sub2API admin, JWT, TOTP, and required upstream settings.
- [x] Add New API session secret and required runtime settings.
- [x] Add Certbot email, staging toggle, domain placeholders, and IP-certificate settings.
- [x] Implement `scripts/validate-env.sh`.
- [x] Reject empty required values, sample passwords, malformed IP addresses, invalid deployment modes, and missing domain values in domain mode.
- [x] Implement secret generation that never overwrites an existing non-placeholder value.

Acceptance:

- [x] A copied `.env.example` can be completed without reading Compose internals.
- [x] Validation fails with actionable messages for every required missing value.
- [x] `.env` remains ignored by Git and is documented as mode `0600`.

## 2. Shared PostgreSQL

- [x] Add a pinned PostgreSQL 16 Alpine service to `compose.yaml`.
- [x] Create an initialization script under `postgres/init/` that creates separate databases and least-privilege users for both applications.
- [x] Make first-run-only initialization behavior explicit.
- [x] Add 4 GB VPS tuning under `config/postgres/`.
- [x] Persist PostgreSQL data.
- [x] Add `pg_isready` health check.
- [x] Do not publish port 5432.
- [x] Configure a reasonable memory limit and Docker log rotation.

Acceptance:

- [ ] A clean-volume startup creates both databases and users.
- [ ] Each application user can access only its intended database.
- [ ] PostgreSQL becomes healthy and survives container recreation.

## 3. Shared Redis

- [x] Add a pinned Redis 7 Alpine service.
- [x] Add password authentication, AOF persistence, `appendfsync everysec`, a 256 MB initial memory cap, and `allkeys-lru`.
- [x] Assign Redis DB 0 to Sub2API and DB 1 to New API.
- [x] Add an authenticated `redis-cli ping` health check.
- [x] Persist Redis data.
- [x] Do not publish port 6379.

Acceptance:

- [ ] Unauthenticated Redis access fails.
- [ ] Authenticated health check succeeds.
- [ ] Both applications can use their assigned DB indexes.

## 4. Sub2API service

- [x] Add the pinned official Sub2API image.
- [x] Configure PostgreSQL, Redis, `AUTO_SETUP`, timezone, admin account, fixed JWT secret, fixed TOTP encryption key, and conservative connection-pool values.
- [x] Persist `/app/data`.
- [x] Add the official `/health` health check.
- [x] Wait for healthy PostgreSQL and Redis before startup.
- [x] Add resource limits, restart policy, `no-new-privileges` where compatible, and log rotation.
- [x] Keep the application port internal to Docker.

Acceptance:

- [ ] Sub2API starts from clean data and reports healthy.
- [ ] Data and login sessions survive container recreation.
- [ ] It is reachable only through Nginx.

## 5. New API service

- [x] Add the pinned official New API image.
- [x] Configure its PostgreSQL DSN, Redis connection string, fixed session secret, node name, timezone, and error logging.
- [x] Persist `/data` and application logs.
- [x] Add `/api/status` health check and validate the success response.
- [x] Wait for healthy PostgreSQL and Redis before startup.
- [x] Add resource limits, restart policy, `no-new-privileges` where compatible, and log rotation.
- [x] Keep the application port internal to Docker.

Acceptance:

- [ ] New API starts from clean data and reports healthy.
- [ ] Data and sessions survive container recreation.
- [ ] It is reachable only through Nginx.

## 6. Docker networking and Compose quality

- [x] Add an `edge` network for Nginx and applications.
- [x] Add an internal `backend` network for applications, PostgreSQL, and Redis.
- [x] Ensure only Nginx publishes host ports.
- [x] Add health-aware startup dependencies without coupling service shutdown.
- [x] Add named volumes or documented bind mounts for all persistent data.
- [x] Add restart policies and resource limits appropriate for 4 GB RAM.
- [x] Ensure `docker compose down` preserves all data.

Acceptance:

- [ ] `docker compose config` succeeds.
- [ ] Host ports 5432, 6379, and application container ports are not published directly.
- [ ] Total configured memory limits leave reasonable capacity for the host OS.

## 7. Nginx IP mode

- [x] Add Nginx configuration templates and reusable proxy/TLS/streaming snippets.
- [x] Publish port 80 for ACME challenge.
- [x] Publish HTTPS port 8080 for Sub2API and 3000 for New API.
- [x] Configure SSE/streaming-safe proxy behavior, long read timeout, forwarded headers, configurable body-size limit, and basic security headers.
- [x] Add a local Nginx health endpoint and Docker health check.
- [x] Add an HTTP-only bootstrap configuration that can start before certificates exist.
- [x] Ensure both IP HTTPS listeners use the same valid IP certificate.

Acceptance:

- [ ] `nginx -t` succeeds for bootstrap and production IP configurations.
- [ ] `https://89.167.21.176:8080` routes to Sub2API.
- [ ] `https://89.167.21.176:3000` routes to New API.
- [ ] Streaming responses are not buffered.

## 8. Certbot IP certificate automation

- [x] Pin Certbot 5.4 or newer.
- [x] Implement webroot-based IP certificate issuance using `--preferred-profile shortlived` and `--ip-address`.
- [x] Support Let's Encrypt staging for safe testing.
- [x] Implement automatic renewal checks at least every 12 hours.
- [x] Reload Nginx only after a successful renewal and valid `nginx -t`.
- [x] Add certificate-expiry checks to project health reporting.
- [x] Make repeated bootstrap runs idempotent and avoid rate-limit loops.

Acceptance:

- [ ] Staging IP certificate issuance succeeds on the VPS.
- [ ] Production IP certificate is trusted for `89.167.21.176`.
- [ ] Renewal dry-run or an equivalent safe validation succeeds.
- [ ] Nginx serves the renewed certificate without downtime.

## 9. Domain migration mode

- [x] Add domain-mode Nginx templates for separate Sub2API and New API hostnames.
- [x] Validate DNS A/AAAA records before certificate requests.
- [x] Add standard Let's Encrypt domain certificate issuance and renewal.
- [x] Redirect domain HTTP traffic to HTTPS except ACME challenge paths.
- [x] Stop publishing 3000/8080 in domain mode; expose only 80/443.
- [x] Implement `make enable-tls` or a clearly named equivalent for mode migration.
- [x] Preserve all application and database volumes during mode changes.

Acceptance:

- [x] Domain-mode configuration can be rendered and validated without affecting IP-mode data.
- [x] Migration and rollback procedures are documented.

## 10. Makefile and lifecycle scripts

- [x] Implement `make help` as the default target.
- [x] Implement `make init`, `up`, `start`, `stop`, `restart`, `down`, `status`, `health`, `logs`, `backup`, `backup-list`, `restore`, `pull`, `update`, `enable-tls`, and `config`.
- [x] Support `SERVICE=name` for logs and restart where appropriate.
- [x] Make all scripts resolve the repository root reliably.
- [x] Add clear errors when Docker, Compose, OpenSSL, curl, or required tools are unavailable.
- [x] Ensure `make update` backs up first, pulls pinned versions, recreates changed containers, and validates health.
- [x] Never make destructive volume deletion part of a normal target.

Acceptance:

- [x] Every command documented in `USER_GUIDE.md` exists and behaves as documented.
- [x] Direct `docker compose` commands remain usable for debugging.

## 11. Health checks and diagnostics

- [x] Implement `scripts/healthcheck.sh`.
- [x] Report Compose state, individual container health, internal endpoints, public HTTPS endpoints, certificate expiry, disk usage, memory usage, and recent OOM events.
- [x] Do not print secrets or authenticated DSNs.
- [x] Return non-zero if a required service or certificate is unhealthy.
- [x] Add concise remediation hints.

Acceptance:

- [ ] Healthy stack returns exit code 0.
- [ ] A deliberately stopped application is detected and returns non-zero.
- [ ] Output is useful to a person unfamiliar with the implementation.

## 12. Local backup and restore

- [x] Implement timestamped local PostgreSQL dumps for both databases.
- [x] Archive Sub2API and New API persistent application data.
- [x] Generate and verify SHA-256 checksums.
- [x] Apply configurable local retention.
- [x] Implement an explicit restore workflow with confirmation or `--yes`.
- [x] Stop only the services required for a consistent restore.
- [x] Document that TLS certificates can be reissued and are not critical backup data.

Acceptance:

- [ ] Backup completes without exposing credentials in process output.
- [ ] Restore succeeds in a clean test environment.
- [ ] Checksums detect a deliberately modified archive.

## 13. Documentation

- [x] Convert `README.md` from planning status into a complete quick start.
- [x] Document Hetzner VPS prerequisites, Docker installation, firewall rules, SSH workflow, swap recommendation, and minimum disk space.
- [x] Document IP-mode initialization and URLs.
- [x] Document all lifecycle commands.
- [x] Document updates, pinned-version changes, rollback, backup, restore, logs, health checks, and common failures.
- [x] Document domain migration without data loss.
- [x] Clearly warn against `docker compose down -v`.
- [x] Add an architecture diagram and service/port table.

Acceptance:

- [x] A new operator can deploy without reading source files.
- [x] Commands in documentation match the implemented Makefile.

## 14. CI and repository checks

- [x] Add GitHub Actions checks for `docker compose config`, ShellCheck, YAML lint, Markdown lint, and secret scanning.
- [x] Add an Nginx configuration test using a container.
- [x] Pin third-party GitHub Actions by commit SHA where practical.
- [x] Add Dependabot or Renovate only if updates remain review-driven and do not auto-deploy.
- [x] Add a pull request template with verification checklist.

Acceptance:

- [ ] CI passes on a clean clone without production secrets.
- [ ] CI fails for an invalid Compose file or shell error.

## 15. VPS preflight — run only when explicitly requested

- [ ] SSH to `alex@89.167.21.176` and record OS version, CPU architecture, RAM, disk, swap, open ports, firewall state, Docker/Compose versions, and existing Docker workloads.
- [ ] Confirm whether user `alex` has passwordless or interactive `sudo`.
- [ ] Check whether ports 80, 443, 3000, and 8080 are already in use.
- [ ] Check whether the public IPv4 is directly assigned and reachable for ACME validation.
- [ ] Do not install, stop, or modify anything during preflight unless separately authorized.
- [ ] Record findings in a non-secret deployment note or issue.

Acceptance:

- [ ] Preflight report identifies blockers without changing server state.

## 16. VPS deployment — run only when explicitly requested

- [ ] Create a dedicated deployment directory such as `/opt/ai-api-relay`.
- [ ] Decide whether deployment files are owned by `alex` or a dedicated service user; use root only where required.
- [ ] Install or configure Docker only after reviewing preflight findings.
- [ ] Copy or clone the repository and create a production `.env` with mode `0600`.
- [ ] Configure 2–4 GB swap if absent and approved.
- [ ] Configure Hetzner Firewall or UFW with minimum required ports.
- [ ] Run staging certificate bootstrap before production issuance.
- [ ] Deploy with `make init`.
- [ ] Verify container health, HTTPS trust, routing, persistence, logs, memory usage, reboot recovery, and backup creation.
- [ ] Record exact deployed image tags and a rollback point.

Acceptance:

- [ ] Both IP HTTPS URLs work from an external client.
- [ ] PostgreSQL and Redis are not publicly reachable.
- [ ] All required containers are healthy after a VPS reboot.
- [ ] Idle memory usage is within the PRD target and no OOM event occurs.

## 17. GitHub publication — run only when explicitly requested

- [ ] Review repository history and working tree for secrets or server-generated data.
- [ ] Create intentional commits grouped by completed TODO sections.
- [ ] Create the GitHub repository with the user-approved owner, name, visibility, description, and license.
- [ ] Add the remote and push the default branch.
- [ ] Configure branch protection and required CI checks if supported.
- [ ] Confirm the published repository contains no `.env`, private key, certificate private key, database dump, backup, or production log.

Acceptance:

- [ ] Fresh clone passes CI and documentation links work.
- [ ] Repository visibility and default branch match the user's request.
