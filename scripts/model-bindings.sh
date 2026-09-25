#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

mode="${1:---check}"
[[ $# -le 1 && ( "${mode}" == --check || "${mode}" == --apply ) ]] ||
  fail "Usage: $0 [--check|--apply]"

load_env "${repo_root}/.env"
require_command python3
require_command shasum

config_file="${repo_root}/config/model-bindings.json"
key_file="${SUB2API_ADMIN_API_KEY_FILE:-${HOME}/.config/ai-api-relay/sub2api-admin-api-key}"
[[ -f "${key_file}" ]] || fail "Missing Sub2API admin API key file: ${key_file}"

bindings="$(python3 - "${config_file}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    config = json.load(source)
aliases = config["aliases"]
if set(aliases) != {"claude-fable", "claude-opus", "claude-sonnet"}:
    raise SystemExit("Expected exactly the three Claude Code aliases")
if any(not isinstance(target, str) or not target.startswith("gpt-6-")
       for target in aliases.values()):
    raise SystemExit("Every alias must target a GPT-6 model")
if not isinstance(config["sub2api_group_id"], int) or config["sub2api_group_id"] <= 0:
    raise SystemExit("sub2api_group_id must be a positive integer")
print(json.dumps(aliases, separators=(",", ":")))
PY
)"
[[ -n "${bindings}" ]] || fail "Invalid model-bindings configuration"

sub2api_args=(--config "${config_file}" --key-file "${key_file}")
sub2api_plan="$(python3 "${script_dir}/model-bindings-sub2api.py" "${sub2api_args[@]}")"
printf '%s\n' "${sub2api_plan}"

newapi_mismatches() {
  docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
    -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" \
    -v "bindings=${bindings}" -At <<'SQL'
SELECT count(*)
FROM jsonb_each_text(:'bindings'::jsonb) b
CROSS JOIN options o
WHERE o.key IN (
    'ModelRatio', 'CompletionRatio', 'CacheRatio', 'CreateCacheRatio',
    'ImageRatio', 'AudioRatio', 'AudioCompletionRatio', 'ModelPrice',
    'billing_setting.billing_mode', 'billing_setting.billing_expr'
)
AND (o.value::jsonb -> b.key) IS DISTINCT FROM (o.value::jsonb -> b.value);
SQL
}

mismatches="$(newapi_mismatches)"
[[ "${mismatches}" =~ ^[0-9]+$ ]] || fail "Could not compare New API pricing options"
log "New API pricing entries differing from GPT-6 targets: ${mismatches}"

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

log "Copying the GPT-6 target billing settings to New API aliases."
docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
  -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" \
  -v "bindings=${bindings}" < "${script_dir}/model-bindings-newapi.sql"

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
  fail "New API billing settings did not persist; backup is at ${backup_dir}"
log "Model bindings applied and verified. Backup: ${backup_dir}"
