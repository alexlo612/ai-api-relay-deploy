#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

mode="${1:-${DEPLOYMENT_MODE:-}}"
load_env "${repo_root}/.env"
mode="${1:-${DEPLOYMENT_MODE}}"

mkdir -p "${repo_root}/config/nginx/rendered/conf.d" "${repo_root}/config/nginx/rendered/snippets"

render_template "${repo_root}/config/nginx/nginx.conf" "${repo_root}/config/nginx/rendered/nginx.conf"
render_template "${repo_root}/config/redis/redis.conf.template" "${repo_root}/config/redis/redis.conf"
for snippet in proxy-common.conf proxy-streaming.conf tls.conf; do
  render_template "${repo_root}/config/nginx/snippets/${snippet}" "${repo_root}/config/nginx/rendered/snippets/${snippet}"
done

case "${mode}" in
  bootstrap)
    render_template "${repo_root}/config/nginx/templates/bootstrap-http.conf.template" "${repo_root}/config/nginx/rendered/conf.d/default.conf"
    ;;
  ip)
    render_template "${repo_root}/config/nginx/templates/ip-production.conf.template" "${repo_root}/config/nginx/rendered/conf.d/default.conf"
    ;;
  domain)
    render_template "${repo_root}/config/nginx/templates/domain-production.conf.template" "${repo_root}/config/nginx/rendered/conf.d/default.conf"
    ;;
  *)
    fail "Unknown render mode: ${mode}. Use bootstrap, ip, or domain."
    ;;
esac

log "Rendered ${mode} configuration."
