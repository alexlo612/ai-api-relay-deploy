# AGENTS.md

## Communication

- Reply in Traditional Chinese. Keep commands, paths, environment variables, and
  code identifiers in English.
- Report completed work, verification results, and remaining blockers.

## Project objective

Maintain a production-minded Docker Compose deployment of Sub2API, New API,
PostgreSQL, and Redis on the Hetzner VPS. The separate `/srv/stacks/vps-infra`
repo owns public Nginx, ports 80/443, hostname TLS, and certificate renewal.

Read `PRD.md`, `TODO.md`, and `USER_GUIDE.md` before implementation. Treat the
PRD as the specification and TODO checkboxes as the implementation sequence.
Keep app deployment details here and shared host infrastructure in its own repo.

## Deployment target

- VPS: `alex@89.167.21.176`
- Relay checkout: `/srv/stacks/ai-api-relay-deploy`
- Compose project: `ai-api-relay`
- Public hostnames: `sub2api.byte612.com`, `newapi.byte612.com`
- External network: `vps-infra_ingress`
- Secret source: `/etc/vps-infra/secrets/ai-api-relay/.env`
- Backup directory: `/home/alex/backups/ai-api-relay`

Never commit SSH keys, passwords, API keys, generated `.env` files, private
certificates, database dumps, backups, or production data.

## Safety and authorization

- Do not inspect or change the VPS unless the user explicitly asks for
  deployment, inspection, or verification. Authorization applies only to the
  stated task and services.
- Before using `sudo` on the VPS, state which operation needs elevated
  privileges. Use ordinary `alex` Docker Compose access for app services.
- Do not alter unrelated services, ports, firewall rules, users, SSH, Docker
  daemon settings, or infra Nginx routes without explicit authorization.
- Check current service and volume state before deployment or image changes.
- Never use `docker compose down -v`, delete persistent volumes, replace the
  production `.env`, or restore a backup without explicit confirmation.
- Back up databases and volumes before image upgrades or database migrations.
- Never print secret values from the production `.env` or container environment.

## Implementation conventions

- Docker Compose is the single source of Relay deployment state.
- Use Compose v2 syntax in `compose.yaml`; omit the obsolete top-level
  `version` field.
- Makefile commands are the supported operator interface and must delegate to
  Compose or scripts.
- Shell scripts use `#!/usr/bin/env bash` and `set -Eeuo pipefail`.
- Scripts validate inputs, quote variables, work from any current directory,
  and remain non-interactive by default where safe.
- Set explicit image tags in `compose.yaml`; keep production overrides in the
  protected external `.env`. Never track `latest`.
- Only `sub2api` and `new-api` join `vps-infra_ingress`. Keep databases and Redis
  private and publish no Relay host ports.
- Every long-running service has a healthcheck, restart policy, resource limit,
  and bounded logs.
- `make down` preserves data. Volume deletion is always a warned destructive
  operation requiring explicit confirmation.
- Keep editable app configuration under `config/`; document values in
  `.env.example`.

## Verification requirements

Before marking a TODO item complete, run relevant checks:

- `docker compose config --quiet`
- `shellcheck scripts/*.sh postgres/init/*.sh`
- YAML lint where available
- Secret scan or a search for committed credentials
- Container health, internal app endpoints, private network membership, and
  unpublished host ports for deployment work

Infra Nginx configuration belongs to `/srv/stacks/vps-infra`; do not recreate
an app-owned Nginx test configuration in this repo. `vps-infra` owns the
external ingress network and all proxy/TLS checks; Relay only declares that
network as external and attaches its web apps. Record verification time,
commands, results, and uncovered paths in `docs/current-state.md` or the
handoff.

## Git workflow

- Keep changes small and scoped. Preserve user changes.
- Do not commit, push, create a GitHub repository, or open a PR unless the user
  explicitly asks.
