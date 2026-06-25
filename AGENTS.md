# AGENTS.md

## Communication

- Reply to the user in Traditional Chinese.
- Keep commands, filenames, environment variable names, and code identifiers in English.
- Report completed work, verification performed, and remaining blockers clearly.

## Project objective

Build a production-minded Docker Compose deployment repository for a 4 GB Hetzner VPS running:

- Sub2API
- New API
- Nginx
- Certbot
- One shared PostgreSQL service with separate databases and users
- One shared Redis service with separate DB indexes

Read `PRD.md`, `TODO.md`, and `USER_GUIDE.md` before implementation. Treat the PRD as the product specification and TODO checkboxes as the implementation sequence.

## Deployment target

- SSH target: `alex@89.167.21.176`
- Initial access mode: public IP with HTTPS
- Sub2API target URL: `https://89.167.21.176:8080`
- New API target URL: `https://89.167.21.176:3000`
- Future mode: two DNS hostnames on ports 80/443
- Server changes must be reproducible from files committed to this repository.

Never commit SSH private keys, passwords, API keys, generated `.env` files, certificates, database dumps, or production data.

## Safety and authorization

- Do not connect to or change the VPS unless the user explicitly asks for deployment, inspection, or verification.
- Before using `sudo` on the VPS, state what requires elevated privileges.
- Prefer the minimum necessary privilege. Do not run application containers as privileged.
- Do not alter unrelated server services, firewall rules, users, SSH configuration, or existing Docker workloads without explicit approval.
- Inspect existing server state before installing packages or binding ports.
- Never run destructive commands such as `docker compose down -v`, delete persistent volumes, overwrite `.env`, or restore a backup without explicit confirmation.
- Back up data before version upgrades or database migrations.

## Implementation conventions

- Docker Compose is the single source of deployment state.
- Use Compose v2 syntax in `compose.yaml`; do not include the obsolete top-level `version` field.
- Makefile commands are the supported user interface and must delegate to Docker Compose or scripts.
- Shell scripts must use `#!/usr/bin/env bash` and `set -Eeuo pipefail`.
- Scripts must be non-interactive by default where safe, validate inputs, quote variables, and work from any current directory.
- Pin container image versions through `.env`; do not silently track `latest`.
- Keep PostgreSQL, Redis, Sub2API, and New API off public host ports. Only Nginx may publish ports.
- Add health checks to every long-running service.
- Preserve data on `make down`; volume deletion must require an explicit destructive command and warning.
- Keep configuration editable under `config/`, with documented values in `.env.example`.

## Verification requirements

Before marking a TODO item complete, run the checks relevant to it:

- `docker compose config`
- `shellcheck scripts/*.sh`
- `nginx -t` in the Nginx container or equivalent test container
- YAML lint where available
- Secret scan or at minimum a search for committed credentials
- Health checks and smoke tests for deployment work

Do not mark an item complete based only on files being created. Record notable validation results in the agent handoff.

## Git workflow

- Keep commits small and scoped to completed TODO groups.
- Do not commit generated secrets or runtime data.
- Do not push, create a GitHub repository, or open a pull request unless the user explicitly asks.
- Preserve user changes and avoid rewriting unrelated files.
