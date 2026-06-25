#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

main() {
  require_command docker
  load_env "${repo_root}/.env"
  "${script_dir}/validate-env.sh"
  "${script_dir}/render-config.sh" "${DEPLOYMENT_MODE}"

  log "Creating backup before update."
  "${script_dir}/backup.sh"

  log "Pulling pinned images."
  docker_compose pull

  log "Recreating changed containers."
  docker_compose up -d

  log "Running health check."
  "${script_dir}/healthcheck.sh"
}

main "$@"
