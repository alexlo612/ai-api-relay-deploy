#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

main() {
  require_command docker
  require_command tar
  require_command shasum
  load_env "${repo_root}/.env"

  local ts backup_dir archive
  ts="$(date -u +%Y%m%d-%H%M%S)"
  backup_dir="${repo_root}/backups/backup-${ts}"
  archive="${backup_dir}.tar.gz"
  mkdir -p "${backup_dir}/postgres" "${backup_dir}/volumes"

  log "Creating PostgreSQL dumps."
  docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" -d "${SUB2API_POSTGRES_DB}" --format=custom > "${backup_dir}/postgres/${SUB2API_POSTGRES_DB}.dump"
  docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" --format=custom > "${backup_dir}/postgres/${NEW_API_POSTGRES_DB}.dump"

  log "Archiving application volumes."
  local project_name="${COMPOSE_PROJECT_NAME//-/_}"
  docker run --rm \
    -v "${project_name}_sub2api_data:/volumes/sub2api:ro" \
    -v "${project_name}_new_api_data:/volumes/new_api:ro" \
    -v "${project_name}_new_api_logs:/volumes/new_api_logs:ro" \
    -v "${backup_dir}/volumes:/backup" \
    alpine:3.22 sh -c 'cd /volumes && tar -czf /backup/app-data.tar.gz sub2api new_api new_api_logs'

  tar -C "${repo_root}/backups" -czf "${archive}" "backup-${ts}"
  (cd "${repo_root}/backups" && shasum -a 256 "backup-${ts}.tar.gz" > "backup-${ts}.tar.gz.sha256")
  rm -rf "${backup_dir}"

  find "${repo_root}/backups" -type f -name 'backup-*.tar.gz*' -mtime "+${BACKUP_RETENTION_DAYS:-14}" -print -delete
  log "Backup created: ${archive}"
}

main "$@"
