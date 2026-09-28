#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

status=0

section() {
  printf '\n== %s ==\n' "$*"
}

check_compose_state() {
  section "Relay services"
  docker_compose ps || status=1
}

check_container_health() {
  section "Container health"
  local ids
  ids="$(docker_compose ps -q || true)"
  if [[ -z "${ids}" ]]; then
    warn "No containers found. Run make init or make up first."
    status=1
    return
  fi
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    local name health state oom
    name="$(docker inspect --format '{{.Name}}' "${id}" | sed 's#^/##')"
    state="$(docker inspect --format '{{.State.Status}}' "${id}")"
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}")"
    oom="$(docker inspect --format '{{.State.OOMKilled}}' "${id}")"
    printf '%-32s state=%-10s health=%-10s oom_killed=%s\n' "${name}" "${state}" "${health}" "${oom}"
    if [[ "${state}" != "running" || ( "${health}" != "healthy" && "${health}" != "none" ) || "${oom}" == "true" ]]; then
      status=1
    fi
  done <<< "${ids}"
}

check_internal_endpoints() {
  section "Application health endpoints"
  if docker_compose exec -T sub2api wget -qO- http://127.0.0.1:8080/health >/dev/null; then
    printf 'sub2api /health ok\n'
  else
    warn 'sub2api /health failed'
    status=1
  fi

  if docker_compose exec -T new-api wget -qO- http://127.0.0.1:3000/api/status \
    | python3 -c 'import json,sys; data=json.load(sys.stdin); sys.exit(0 if data.get("success") else 1)' >/dev/null; then
    printf 'new-api /api/status ok\n'
  else
    warn 'new-api /api/status failed'
    status=1
  fi
}

check_host_resources() {
  section "Host resources"
  df -h .
  if command -v free >/dev/null 2>&1; then
    free -h
  else
    vm_stat || true
  fi
  docker stats --no-stream || true
}

main() {
  require_command docker
  require_command python3
  load_env "${repo_root}/.env"
  check_compose_state
  check_container_health
  check_internal_endpoints
  check_host_resources

  if (( status == 0 )); then
    log "Health check passed."
  else
    warn "Health check found issues. Check make logs SERVICE=<name> and docker compose ps."
  fi
  exit "${status}"
}

main "$@"
