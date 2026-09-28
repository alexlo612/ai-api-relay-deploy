#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

errors=0

error() {
  printf '[ERROR] %s\n' "$*" >&2
  errors=$((errors + 1))
}

require_var() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "${value}" ]]; then
    error "${name} is required and must not be empty."
  fi
}

require_configured_secret() {
  local name="$1"
  local value="${!name:-}"
  require_var "${name}"
  if is_placeholder "${value}"; then
    error "${name} still contains a placeholder; run make init or set a strong value."
  fi
}

require_secret() {
  local name="$1"
  local value="${!name:-}"
  require_configured_secret "${name}"
  if (( ${#value} < 24 )); then
    error "${name} should be at least 24 characters."
  fi
}

require_int() {
  local name="$1"
  local value="${!name:-}"
  require_var "${name}"
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    error "${name} must be an integer."
  fi
}

valid_bool() {
  local name="$1"
  local value="${!name:-}"
  if [[ ! "${value}" =~ ^(true|false)$ ]]; then
    error "${name} must be true or false."
  fi
}

load_env "${ENV_FILE:-${repo_root}/.env}"

for name in COMPOSE_PROJECT_NAME TZ POSTGRES_IMAGE_TAG REDIS_IMAGE_TAG SUB2API_IMAGE_TAG NEW_API_IMAGE_TAG; do
  require_var "${name}"
done
for name in POSTGRES_IMAGE_TAG REDIS_IMAGE_TAG SUB2API_IMAGE_TAG NEW_API_IMAGE_TAG; do
  value="${!name}"
  if [[ "${value}" == "latest" || "${value}" == change-me* ]]; then
    error "${name} must be pinned to an explicit reviewed image tag or digest."
  fi
done

for name in POSTGRES_DB POSTGRES_USER SUB2API_POSTGRES_DB SUB2API_POSTGRES_USER NEW_API_POSTGRES_DB NEW_API_POSTGRES_USER; do
  require_var "${name}"
done

for name in POSTGRES_PASSWORD SUB2API_POSTGRES_PASSWORD NEW_API_POSTGRES_PASSWORD REDIS_PASSWORD SUB2API_JWT_SECRET SUB2API_TOTP_ENCRYPTION_KEY NEW_API_SESSION_SECRET NEW_API_CRYPTO_SECRET; do
  require_secret "${name}"
done
require_configured_secret SUB2API_ADMIN_PASSWORD

for name in SUB2API_REDIS_DB NEW_API_REDIS_DB SUB2API_DB_MAX_OPEN_CONNS SUB2API_DB_MAX_IDLE_CONNS REDIS_POOL_SIZE REDIS_MIN_IDLE_CONNS BACKUP_RETENTION_DAYS; do
  require_int "${name}"
done

for name in NEW_API_ERROR_LOG_ENABLED NEW_API_BATCH_UPDATE_ENABLED SUB2API_URL_ALLOWLIST_ENABLED; do
  valid_bool "${name}"
done

if [[ "${SUB2API_POSTGRES_DB}" == "${NEW_API_POSTGRES_DB}" ]]; then
  error "SUB2API_POSTGRES_DB and NEW_API_POSTGRES_DB must be different."
fi
if [[ "${SUB2API_POSTGRES_USER}" == "${NEW_API_POSTGRES_USER}" ]]; then
  error "SUB2API_POSTGRES_USER and NEW_API_POSTGRES_USER must be different."
fi
if [[ "${SUB2API_REDIS_DB}" == "${NEW_API_REDIS_DB}" ]]; then
  error "SUB2API_REDIS_DB and NEW_API_REDIS_DB must be different."
fi
if (( SUB2API_REDIS_DB < 0 || SUB2API_REDIS_DB > 15 || NEW_API_REDIS_DB < 0 || NEW_API_REDIS_DB > 15 )); then
  error "Redis DB indexes must be between 0 and 15."
fi

if [[ ! "${SUB2API_ADMIN_EMAIL:-}" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
  error "SUB2API_ADMIN_EMAIL must be a valid email address."
fi

if [[ ! "${REDIS_MAXMEMORY:-256mb}" =~ ^[0-9]+[kKmMgG]?[bB]?$ ]]; then
  error "REDIS_MAXMEMORY should look like 256mb."
fi

if (( errors > 0 )); then
  fail "Environment validation failed with ${errors} error(s)."
fi

log "Environment validation passed."
