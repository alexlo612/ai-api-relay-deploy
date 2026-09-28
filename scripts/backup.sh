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

  local ts backup_dir archive backup_root
  backup_root="${BACKUP_DIR:-${repo_root}/backups}"
  ts="$(date -u +%Y%m%d-%H%M%S)"
  backup_dir="${backup_root}/backup-${ts}"
  archive="${backup_dir}.tar.gz"
  mkdir -p "${backup_dir}/postgres" "${backup_dir}/volumes"

  log "Creating PostgreSQL dumps."
  docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" -d "${SUB2API_POSTGRES_DB}" --format=custom > "${backup_dir}/postgres/${SUB2API_POSTGRES_DB}.dump"
  docker_compose exec -T postgres pg_dump -U "${POSTGRES_USER}" -d "${NEW_API_POSTGRES_DB}" --format=custom > "${backup_dir}/postgres/${NEW_API_POSTGRES_DB}.dump"

  log "Archiving application volumes."
  local sub2api_volume new_api_volume new_api_logs_volume redis_volume
  sub2api_volume="$(compose_volume_name sub2api_data)"
  new_api_volume="$(compose_volume_name new_api_data)"
  new_api_logs_volume="$(compose_volume_name new_api_logs)"
  redis_volume="$(compose_volume_name redis_data)"
  docker run --rm \
    -v "${sub2api_volume}:/volumes/sub2api:ro" \
    -v "${new_api_volume}:/volumes/new_api:ro" \
    -v "${new_api_logs_volume}:/volumes/new_api_logs:ro" \
    -v "${redis_volume}:/volumes/redis:ro" \
    -v "${backup_dir}/volumes:/backup" \
    alpine:3.22 sh -c 'cd /volumes && tar -czf /backup/app-data.tar.gz sub2api new_api new_api_logs redis'

  tar -C "${backup_root}" -czf "${archive}" "backup-${ts}"
  (cd "${backup_root}" && shasum -a 256 "backup-${ts}.tar.gz" > "backup-${ts}.tar.gz.sha256")
  rm -rf "${backup_dir}"

  find "${backup_root}" -type f -name 'backup-*.tar.gz*' -mtime "+${BACKUP_RETENTION_DAYS:-14}" -print -delete
  log "Backup created: ${archive}"
}

main "$@"
