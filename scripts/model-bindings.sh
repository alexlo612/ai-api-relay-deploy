#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

mode="${1:---check}"
[[ $# -le 1 && ( "${mode}" == --check || "${mode}" == --apply ||
                   "${mode}" == --apply-sub2api ||
                   "${mode}" == --prune-legacy ) ]] ||
  fail "Usage: $0 [--check|--apply|--apply-sub2api|--prune-legacy]"

load_env "${repo_root}/.env"
require_command python3
require_command shasum

config_file="${repo_root}/config/model-bindings.json"
config="$(python3 - "${config_file}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    config = json.load(source)
aliases = config["aliases"]
if set(aliases) != {
    "claude-fable-5-1", "claude-opus-5-5", "claude-sonnet-5",
    "coding-fast", "coding-pro", "coding-max",
}:
    raise SystemExit("Expected three versioned Claude and three coding aliases")
if any(not isinstance(target, str) or not target.startswith("gpt-6-")
       for target in aliases.values()):
    raise SystemExit("Every alias must target a GPT-6 model")
if not isinstance(config["sub2api_group_id"], int) or config["sub2api_group_id"] <= 0:
    raise SystemExit("sub2api_group_id must be a positive integer")
if config["channels"] != {"openai": 6, "claude": 8}:
    raise SystemExit("Review channel IDs before changing this deployment")
if config["legacy_aliases"] != {
    "claude-fable": aliases["claude-fable-5-1"],
    "claude-opus": aliases["claude-opus-5-5"],
    "claude-sonnet": aliases["claude-sonnet-5"],
}:
    raise SystemExit("Legacy bindings differ from the previous deployment")
print(json.dumps(config, separators=(",", ":")))
PY
)"
[[ -n "${config}" ]] || fail "Invalid model-bindings configuration"

if [[ "${mode}" == --prune-legacy ]]; then
  legacy_count="$(docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
    -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" \
    -v "config=${config}" -At < "${script_dir}/model-bindings-newapi-legacy-check.sql")"
  [[ "${legacy_count}" =~ ^[0-9]+$ ]] || fail "Could not inspect New API legacy aliases"
  upstream_count="$(docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
    -U "${POSTGRES_USER}" -d "${SUB2API_POSTGRES_DB}" \
    -v "config=${config}" -At < "${script_dir}/model-bindings-sub2api-legacy-check.sql")"
  [[ "${upstream_count}" =~ ^[0-9]+$ ]] || fail "Could not inspect Sub2API legacy aliases"
  if [[ "${legacy_count}" == 0 && "${upstream_count}" == 0 ]]; then
    log "Legacy aliases are absent from both relays; no backup or restart needed."
    exit 0
  fi
  umask 077
  backup_dir="${repo_root}/backups/model-bindings-legacy-$(date -u +%Y%m%d-%H%M%S)"
  mkdir -p "${backup_dir}"
  dumps=()
  if (( legacy_count > 0 )); then
    log "Backing up New API before removing ${legacy_count} legacy references."
    docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" \
      -d "${NEW_API_POSTGRES_DB}" --format=custom > "${backup_dir}/newapi.dump"
    dumps+=(newapi.dump)
  fi
  if (( upstream_count > 0 )); then
    log "Backing up Sub2API before removing legacy account mappings."
    docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" \
      -d "${SUB2API_POSTGRES_DB}" --format=custom > "${backup_dir}/sub2api.dump"
    dumps+=(sub2api.dump)
  fi
  (cd "${backup_dir}" && shasum -a 256 "${dumps[@]}" > SHA256SUMS &&
    shasum -a 256 -c SHA256SUMS)
  if (( upstream_count > 0 )); then
    docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
      -U "${POSTGRES_USER}" -d "${SUB2API_POSTGRES_DB}" \
      -v "config=${config}" < "${script_dir}/model-bindings-sub2api-prune-legacy.sql"
    log "Restarting Sub2API to refresh the advertised model list."
    docker_compose restart sub2api
    sub2api_container="$(docker_compose ps -q sub2api)"
    [[ -n "${sub2api_container}" ]] || fail "Sub2API container is missing after restart"
    for _ in {1..45}; do
      if [[ "$(docker inspect --format '{{.State.Health.Status}}' "${sub2api_container}")" == healthy ]]; then
        break
      fi
      sleep 2
    done
    [[ "$(docker inspect --format '{{.State.Health.Status}}' "${sub2api_container}")" == healthy ]] ||
      fail "Sub2API did not return to healthy; backup is at ${backup_dir}"
  fi
  if (( legacy_count > 0 )); then
    docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
      -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" \
      -v "config=${config}" < "${script_dir}/model-bindings-newapi-prune-legacy.sql"
    log "Restarting New API to refresh the model and pricing caches."
    docker_compose restart new-api
    newapi_container="$(docker_compose ps -q new-api)"
    [[ -n "${newapi_container}" ]] || fail "New API container is missing after restart"
    for _ in {1..45}; do
      if [[ "$(docker inspect --format '{{.State.Health.Status}}' "${newapi_container}")" == healthy ]]; then
        break
      fi
      sleep 2
    done
    [[ "$(docker inspect --format '{{.State.Health.Status}}' "${newapi_container}")" == healthy ]] ||
      fail "New API did not return to healthy; backup is at ${backup_dir}"
  fi
  [[ "$(docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
    -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" \
    -v "config=${config}" -At < "${script_dir}/model-bindings-newapi-legacy-check.sql")" == 0 ]] ||
    fail "New API legacy aliases remain; backup is at ${backup_dir}"
  [[ "$(docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
    -U "${POSTGRES_USER}" -d "${SUB2API_POSTGRES_DB}" \
    -v "config=${config}" -At < "${script_dir}/model-bindings-sub2api-legacy-check.sql")" == 0 ]] ||
    fail "Sub2API legacy aliases remain; backup is at ${backup_dir}"
  log "Legacy aliases removed and verified. Backup: ${backup_dir}"
  exit 0
fi

key_file="${SUB2API_ADMIN_API_KEY_FILE:-${HOME}/.config/ai-api-relay/sub2api-admin-api-key}"
[[ -f "${key_file}" ]] || fail "Missing Sub2API admin API key file: ${key_file}"

sub2api_args=(--config "${config_file}" --key-file "${key_file}")
sub2api_plan="$(python3 "${script_dir}/model-bindings-sub2api.py" "${sub2api_args[@]}")"
printf '%s\n' "${sub2api_plan}"

if [[ "${mode}" == --apply-sub2api ]]; then
  if [[ "${sub2api_plan}" == "Sub2API exact mappings already match the desired aliases." ]]; then
    log "Sub2API mappings already match; no backup needed."
    exit 0
  fi
  umask 077
  backup_dir="${repo_root}/backups/model-bindings-sub2api-$(date -u +%Y%m%d-%H%M%S)"
  mkdir -p "${backup_dir}"
  log "Backing up Sub2API before updating Messages-dispatch mappings."
  docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" \
    -d "${SUB2API_POSTGRES_DB}" --format=custom > "${backup_dir}/sub2api.dump"
  (cd "${backup_dir}" && shasum -a 256 sub2api.dump > SHA256SUMS &&
    shasum -a 256 -c SHA256SUMS)
  python3 "${script_dir}/model-bindings-sub2api.py" "${sub2api_args[@]}" --apply
  log "Sub2API mappings verified. Backup: ${backup_dir}"
  exit 0
fi

newapi_mismatches() {
  docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
    -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" \
    -v "config=${config}" -At < "${script_dir}/model-bindings-newapi-check.sql"
}

mismatches="$(newapi_mismatches)"
[[ "${mismatches}" =~ ^[0-9]+$ ]] || fail "Could not compare New API pricing options"
log "New API routing/pricing differences: ${mismatches}"

if [[ "${mode}" == --check ]]; then
  exit 0
fi
if [[ "${mismatches}" == 0 && "${sub2api_plan}" == "Sub2API exact mappings already match the desired aliases." ]]; then
  log "Model bindings already match; no restart or backup needed."
  exit 0
fi

umask 077
backup_dir="${repo_root}/backups/model-bindings-$(date -u +%Y%m%d-%H%M%S)"
mkdir -p "${backup_dir}"
log "Backing up both databases before changing model settings."
docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" -d "${SUB2API_POSTGRES_DB}" --format=custom > "${backup_dir}/sub2api.dump"
docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" --format=custom > "${backup_dir}/newapi.dump"
(cd "${backup_dir}" && shasum -a 256 sub2api.dump newapi.dump > SHA256SUMS && shasum -a 256 -c SHA256SUMS)

log "Updating New API channels, abilities, and GPT-6-based alias billing."
docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
  -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" \
  -v "config=${config}" < "${script_dir}/model-bindings-newapi.sql"

log "Restarting New API to load the updated billing settings."
docker_compose restart new-api
newapi_container="$(docker_compose ps -q new-api)"
[[ -n "${newapi_container}" ]] || fail "New API container is missing after restart"
for _ in {1..45}; do
  if [[ "$(docker inspect --format '{{.State.Health.Status}}' "${newapi_container}")" == healthy ]]; then
    break
  fi
  sleep 2
done
[[ "$(docker inspect --format '{{.State.Health.Status}}' "${newapi_container}")" == healthy ]] ||
  fail "New API did not return to healthy; backup is at ${backup_dir}"

log "Applying Sub2API exact Messages-dispatch mappings."
python3 "${script_dir}/model-bindings-sub2api.py" "${sub2api_args[@]}" --apply
[[ "$(newapi_mismatches)" == 0 ]] ||
  fail "New API routing/pricing settings did not persist; backup is at ${backup_dir}"
log "Model bindings applied and verified. Backup: ${backup_dir}"
