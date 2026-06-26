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
  if [[ "${DEPLOYMENT_MODE:-ip}" == "domain" ]]; then
    printf -- '-f\n%s\n' "${repo_root}/compose.domain.yaml"
  fi
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

render_template() {
  local source="$1"
  local target="$2"
  # Keep this list literal so envsubst replaces only deployment placeholders,
  # not Nginx runtime variables such as $host and $remote_addr.
  local variables
  # shellcheck disable=SC2016
  variables='${REDIS_MAXMEMORY} ${REQUEST_BODY_SIZE} ${PROXY_READ_TIMEOUT} ${PROXY_SEND_TIMEOUT} ${SERVER_PUBLIC_IP} ${IP_CERT_NAME} ${SUB2API_DOMAIN} ${NEW_API_DOMAIN} ${DOMAIN_CERT_NAME}'
  if command -v envsubst >/dev/null 2>&1; then
    envsubst "${variables}" < "${source}" > "${target}"
    return
  fi
  require_command python3
  SOURCE_PATH="${source}" TARGET_PATH="${target}" python3 - <<'PY'
import os
import re
from pathlib import Path

source = Path(os.environ["SOURCE_PATH"])
target = Path(os.environ["TARGET_PATH"])
pattern = re.compile(r"\$\{(REDIS_MAXMEMORY|REQUEST_BODY_SIZE|PROXY_READ_TIMEOUT|PROXY_SEND_TIMEOUT|SERVER_PUBLIC_IP|IP_CERT_NAME|SUB2API_DOMAIN|NEW_API_DOMAIN|DOMAIN_CERT_NAME)\}")

def repl(match):
    return os.environ.get(match.group(1), match.group(0))

target.write_text(pattern.sub(repl, source.read_text()))
PY
}

redact() {
  sed -E 's#(postgresql://[^:]+:)[^@]+#\1REDACTED#g; s#(redis://:)[^@]+#\1REDACTED#g; s#(PASSWORD|SECRET|KEY|TOKEN)=([^[:space:]]+)#\1=REDACTED#g'
}

compose_volume_name() {
  local volume="$1"
  local name
  require_command python3
  name="$(docker_compose config --format json | python3 -c 'import json,sys; volume=sys.argv[1]; data=json.load(sys.stdin); print(data["volumes"][volume].get("name", ""))' "${volume}")"
  [[ -n "${name}" ]] || fail "Unable to resolve Compose volume name: ${volume}"
  printf '%s\n' "${name}"
}
