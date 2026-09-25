#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

[[ $# -eq 0 || ( $# -eq 1 && "$1" == "--apply" ) ]] ||
  fail "Usage: $0 [--apply]"
load_env "${repo_root}/.env"

# Keep the earlier account-suspension allowlist out of this cleanup.
where_clause="t.deleted_at IS NULL AND t.status = 1 AND u.status = 2 AND u.deleted_at IS NULL AND u.username NOT IN ('admin', 'alex-user-test', 'alex-user-test-02')"
count="$(docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" \
  -d "${NEW_API_POSTGRES_DB}" -At -c \
  "SELECT count(*) FROM tokens t JOIN users u ON u.id = t.user_id WHERE ${where_clause}")"
log "Active tokens owned by suspended, non-allowlisted users: ${count}"
[[ "${count}" =~ ^[0-9]+$ ]] || fail "Unexpected count from PostgreSQL."
[[ $# -eq 1 && "$1" == "--apply" && "${count}" -gt 0 ]] || exit 0

require_command shasum
umask 077
backup_dir="${repo_root}/backups/newapi-token-revoke-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 700 "${backup_dir}"
docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" \
  -d "${NEW_API_POSTGRES_DB}" --format=custom > "${backup_dir}/newapi.dump"
docker_compose exec -T postgres pg_restore --list < "${backup_dir}/newapi.dump" > /dev/null
(cd "${backup_dir}" && shasum -a 256 newapi.dump > SHA256SUMS)
log "Verified pre-change backup: ${backup_dir}"

docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" \
  -d "${NEW_API_POSTGRES_DB}" -At -c \
  "WITH revoked AS (
     UPDATE tokens t SET status = 2 FROM users u
     WHERE t.user_id = u.id AND ${where_clause}
     RETURNING t.id
   ) SELECT count(*) FROM revoked"
log "Re-run this script without --apply to verify zero remaining tokens."
warn "New API caches token metadata in Redis; cached entries may persist briefly. Suspended user status remains the primary immediate block."
