#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

replace_env_value() {
  local key="$1"
  local value="$2"
  local env_file="${repo_root}/.env"
  if [[ -L "${env_file}" ]]; then
    env_file="$(readlink -f "${env_file}")"
  fi
  local escaped
  escaped="$(printf '%s' "${value}" | sed 's/[&\\]/\\&/g')"
  if grep -q "^${key}=" "${env_file}"; then
    sed -i.bak "s|^${key}=.*|${key}=${escaped}|" "${env_file}"
    rm -f "${env_file}.bak"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${env_file}"
  fi
  chmod 600 "${env_file}"
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
  docker_compose config >/dev/null

  log "Starting application and data services on vps-infra_ingress."
  docker_compose up -d --wait --wait-timeout 180 --remove-orphans

  log "Bootstrap completed. Shared ingress TLS and hostname routes are managed by vps-infra."
  "${script_dir}/healthcheck.sh" || warn "Full health check reported issues. Inspect service logs and the shared ingress with make logs SERVICE=<name>."
}

main "$@"
