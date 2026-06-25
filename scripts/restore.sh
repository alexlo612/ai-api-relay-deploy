#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/restore.sh --file backups/backup-YYYYMMDD-HHMMSS.tar.gz [--yes]

Restores PostgreSQL dumps and application data from a local backup archive.
This is destructive for application data and databases. It never deletes Docker
volumes, but it replaces their contents.
USAGE
}

file=""
yes=false
while (($#)); do
  case "$1" in
    --file)
      file="${2:-}"
      shift 2
      ;;
    --yes)
      yes=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      fail "Unknown restore argument: $1"
      ;;
  esac
done

[[ -n "${file}" ]] || { usage; fail "--file is required."; }
[[ -f "${file}" ]] || fail "Backup archive not found: ${file}"
[[ -f "${file}.sha256" ]] || fail "Checksum file not found: ${file}.sha256"

load_env "${repo_root}/.env"

if [[ "${yes}" != "true" ]]; then
  printf 'Restore %s into the current stack? Type RESTORE to continue: ' "${file}"
  read -r answer
  [[ "${answer}" == "RESTORE" ]] || fail "Restore cancelled."
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

log "Verifying checksum."
(cd "$(dirname "${file}")" && shasum -a 256 -c "$(basename "${file}").sha256")

tar -C "${workdir}" -xzf "${file}"
backup_root="$(find "${workdir}" -maxdepth 1 -type d -name 'backup-*' | head -n 1)"
[[ -n "${backup_root}" ]] || fail "Backup archive does not contain backup-* directory."

log "Stopping applications for consistent restore."
docker_compose stop nginx sub2api new-api

project_name="${COMPOSE_PROJECT_NAME//-/_}"
log "Restoring application data volumes."
docker run --rm \
  -v "${project_name}_sub2api_data:/restore/sub2api" \
  -v "${project_name}_new_api_data:/restore/new_api" \
  -v "${project_name}_new_api_logs:/restore/new_api_logs" \
  -v "${backup_root}/volumes:/backup:ro" \
  alpine:3.22 sh -c 'set -e; find /restore/sub2api /restore/new_api /restore/new_api_logs -mindepth 1 -maxdepth 1 -exec rm -rf {} +; tar -xzf /backup/app-data.tar.gz -C /restore'

log "Restoring PostgreSQL databases."
docker_compose up -d postgres
docker_compose exec -T postgres pg_restore -U "${POSTGRES_USER}" -d "${SUB2API_POSTGRES_DB}" --clean --if-exists < "${backup_root}/postgres/${SUB2API_POSTGRES_DB}.dump"
docker_compose exec -T postgres pg_restore -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" --clean --if-exists < "${backup_root}/postgres/${NEW_API_POSTGRES_DB}.dump"

log "Starting stack after restore."
docker_compose up -d
"${script_dir}/healthcheck.sh"
