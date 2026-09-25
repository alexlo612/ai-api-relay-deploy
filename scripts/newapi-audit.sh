#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${script_dir}/common.sh"

load_env "${repo_root}/.env"

docker_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" \
  -d "${NEW_API_POSTGRES_DB}" -At -F ' | ' <<'SQL'
SELECT 'setting', key, value
FROM options
WHERE key IN ('RegisterEnabled', 'EmailVerificationEnabled', 'SelfUseModeEnabled',
              'DemoSiteEnabled', 'QuotaForNewUser', 'checkin_setting.enabled')
ORDER BY key;

SELECT 'users', 'status=' || status, count(*)
FROM users WHERE deleted_at IS NULL GROUP BY status ORDER BY status;

SELECT 'active tokens', 'owner status=' || u.status, count(*)
FROM tokens t JOIN users u ON u.id = t.user_id
WHERE t.deleted_at IS NULL AND t.status = 1
GROUP BY u.status ORDER BY u.status;

SELECT 'active token controls', 'unlimited quota',
       count(*) FILTER (WHERE t.unlimited_quota)
FROM tokens t JOIN users u ON u.id = t.user_id
WHERE t.deleted_at IS NULL AND t.status = 1 AND u.status = 1;

SELECT 'active token controls', 'never expires',
       count(*) FILTER (WHERE t.expired_time = -1)
FROM tokens t JOIN users u ON u.id = t.user_id
WHERE t.deleted_at IS NULL AND t.status = 1 AND u.status = 1;

SELECT 'active token controls', 'unrestricted models',
       count(*) FILTER (WHERE NOT t.model_limits_enabled)
FROM tokens t JOIN users u ON u.id = t.user_id
WHERE t.deleted_at IS NULL AND t.status = 1 AND u.status = 1;

WITH active_models AS (
  SELECT DISTINCT trim(unnest(string_to_array(models, ','))) AS name
  FROM channels WHERE status = 1
), prices AS (
  SELECT value::jsonb AS data FROM options WHERE key = 'ModelPrice'
), ratios AS (
  SELECT value::jsonb AS data FROM options WHERE key = 'ModelRatio'
), billing AS (
  SELECT value::jsonb AS data FROM options WHERE key = 'billing_setting.billing_mode'
)
SELECT 'routed model', name,
       CASE WHEN prices.data ? name THEN 'fixed price'
            WHEN ratios.data ? name THEN 'ratio'
            ELSE 'UNSET' END || ', billing=' ||
       coalesce(billing.data ->> name, 'default')
FROM active_models CROSS JOIN prices CROSS JOIN ratios CROSS JOIN billing
WHERE name <> '' ORDER BY name;
SQL
