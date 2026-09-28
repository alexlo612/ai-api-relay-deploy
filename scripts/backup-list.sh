#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

main() {
  load_env "${repo_root}/.env"
  local backup_root="${BACKUP_DIR:-${repo_root}/backups}"
  if [[ ! -d "${backup_root}" ]]; then
    log "Backup directory does not exist yet: ${backup_root}"
    return
  fi
  find "${backup_root}" -maxdepth 1 -type f -name 'backup-*.tar.gz' -print | sort
}

main "$@"
