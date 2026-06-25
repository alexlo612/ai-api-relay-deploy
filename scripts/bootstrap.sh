#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

replace_env_value() {
  local key="$1"
  local value="$2"
  local env_file="${repo_root}/.env"
  local escaped
  escaped="$(printf '%s' "${value}" | sed 's/[&\\]/\\&/g')"
  if grep -q "^${key}=" "${env_file}"; then
    sed -i.bak "s|^${key}=.*|${key}=${escaped}|" "${env_file}"
    rm -f "${env_file}.bak"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${env_file}"
  fi
}

generate_secret_if_needed() {
  local key="$1"
  local current="${!key:-}"
  if is_placeholder "${current}"; then
    local generated
    generated="$(openssl rand -hex 32)"
    replace_env_value "${key}" "${generated}"
    log "Generated ${key}."
  else
    log "Keeping existing ${key}."
  fi
}

ensure_env() {
  if [[ ! -f "${repo_root}/.env" ]]; then
    cp "${repo_root}/.env.example" "${repo_root}/.env"
    chmod 600 "${repo_root}/.env"
    log "Created .env from .env.example. Edit public settings before production use."
  fi
}

main() {
  require_command docker
  require_command openssl

  ensure_env
  load_env "${repo_root}/.env"

  for key in POSTGRES_PASSWORD SUB2API_POSTGRES_PASSWORD NEW_API_POSTGRES_PASSWORD REDIS_PASSWORD SUB2API_ADMIN_PASSWORD SUB2API_JWT_SECRET SUB2API_TOTP_ENCRYPTION_KEY NEW_API_SESSION_SECRET NEW_API_CRYPTO_SECRET; do
    generate_secret_if_needed "${key}"
  done

  load_env "${repo_root}/.env"
  "${script_dir}/validate-env.sh"
  "${script_dir}/render-config.sh" bootstrap
  docker_compose config >/dev/null

  log "Starting data and application services."
  docker_compose up -d postgres redis sub2api new-api

  log "Starting HTTP-only bootstrap Nginx for ACME challenge."
  docker_compose up -d --no-deps nginx

  log "Bootstrap completed for ${DEPLOYMENT_MODE} mode. Issue certificates with: make enable-tls"
  "${script_dir}/healthcheck.sh" || warn "Initial health check reported issues; this is expected until certificates and public endpoints are ready. Inspect with make logs SERVICE=<name>."
}

main "$@"
