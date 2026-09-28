#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir
repo_root="$(cd "${script_dir}/.." && pwd)"
readonly repo_root

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "Required command not found: ${cmd}"
}

compose_files() {
  printf -- '-f\n%s\n' "${repo_root}/compose.yaml"
}

docker_compose() {
  require_command docker
  docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 plugin is required. Install Docker Engine with the compose plugin."
  local files=()
  while IFS= read -r item; do
    files+=("${item}")
  done < <(compose_files)
  docker compose "${files[@]}" "$@"
}

load_env() {
  local env_file="${1:-${repo_root}/.env}"
  [[ -f "${env_file}" ]] || fail "Missing ${env_file}. Copy .env.example to .env and edit it first."
  set -a
  # shellcheck disable=SC1090
  source "${env_file}"
  set +a
}

is_placeholder() {
  local value="${1:-}"
  [[ -z "${value}" ]] && return 0
  [[ "${value}" == change-me* ]] && return 0
  [[ "${value}" == *your-domain.com* ]] && return 0
  [[ "${value}" == admin@example.com ]] && return 0
  return 1
}

compose_volume_name() {
  local volume="$1"
  local name
  require_command python3
  name="$(docker_compose config --format json | python3 -c 'import json,sys; volume=sys.argv[1]; data=json.load(sys.stdin); print(data["volumes"][volume].get("name", ""))' "${volume}")"
  [[ -n "${name}" ]] || fail "Unable to resolve Compose volume name: ${volume}"
  printf '%s\n' "${name}"
}
