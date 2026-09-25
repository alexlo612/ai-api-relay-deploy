#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/certbot.sh issue|renew|expiry

issue   Request or refresh the certificate for DEPLOYMENT_MODE.
renew   Run a safe renewal check, test Nginx, then reload Nginx if renewal succeeds.
expiry  Print certificate expiry information from the certbot container.
USAGE
}

staging_args=()
certbot_email_args=()

prepare_args() {
  staging_args=()
  certbot_email_args=(--email "${LETSENCRYPT_EMAIL}" --agree-tos --no-eff-email --non-interactive)
  if [[ "${LETSENCRYPT_STAGING}" == "true" ]]; then
    staging_args=(--staging)
  fi
}

ensure_bootstrap_nginx() {
  "${script_dir}/render-config.sh" bootstrap
  docker_compose up -d --no-deps nginx
}

nginx_reload_if_valid() {
  docker_compose exec -T nginx nginx -t
  docker_compose exec -T nginx nginx -s reload
}

issue_ip() {
  ensure_bootstrap_nginx
  docker_compose run --rm --entrypoint certbot certbot certonly \
    "${staging_args[@]}" \
    "${certbot_email_args[@]}" \
    --preferred-profile "${IP_CERT_PREFERRED_PROFILE:-shortlived}" \
    --webroot --webroot-path /var/www/certbot \
    --cert-name "${IP_CERT_NAME}" \
    --ip-address "${SERVER_PUBLIC_IP}"
  "${script_dir}/render-config.sh" ip
  nginx_reload_if_valid
}

check_domain_dns() {
  local host ip
  for host in "${SUB2API_DOMAIN}" "${NEW_API_DOMAIN}"; do
    ip="$(getent ahostsv4 "${host}" 2>/dev/null | sed -n '1s/[[:space:]].*//p' || true)"
    if [[ -z "${ip}" ]] && command -v dig >/dev/null 2>&1; then
      ip="$(dig +short A "${host}" | sed -n '1p')"
    fi
    if [[ "${ip}" != "${SERVER_PUBLIC_IP}" ]]; then
      fail "${host} A record resolves to '${ip:-none}', expected ${SERVER_PUBLIC_IP}. Fix DNS before certificate issuance."
    fi
  done
}

issue_domain() {
  check_domain_dns
  "${script_dir}/render-config.sh" bootstrap
  docker_compose up -d --no-deps nginx
  docker_compose run --rm --entrypoint certbot certbot certonly \
    "${staging_args[@]}" \
    "${certbot_email_args[@]}" \
    --webroot --webroot-path /var/www/certbot \
    --cert-name "${DOMAIN_CERT_NAME}" \
    -d "${SUB2API_DOMAIN}" \
    -d "${NEW_API_DOMAIN}"
  "${script_dir}/render-config.sh" domain
  nginx_reload_if_valid
}

renew() {
  docker_compose run --rm --entrypoint certbot certbot renew --webroot -w /var/www/certbot
  nginx_reload_if_valid
}

expiry() {
  docker_compose run --rm --no-deps --entrypoint certbot certbot certificates
}

main() {
  local action="${1:-}"
  if [[ -z "${action}" || "${action}" == "--help" || "${action}" == "-h" ]]; then
    usage
    exit 0
  fi

  load_env "${repo_root}/.env"

  case "${action}" in
    issue)
      "${script_dir}/validate-env.sh"
      prepare_args
      if [[ "${DEPLOYMENT_MODE}" == "domain" ]]; then
        issue_domain
      else
        issue_ip
      fi
      ;;
    renew)
      renew
      ;;
    expiry)
      expiry
      ;;
    *)
      usage
      fail "Unknown certbot action: ${action}"
      ;;
  esac
}

main "$@"
