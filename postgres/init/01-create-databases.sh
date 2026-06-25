#!/usr/bin/env bash
set -Eeuo pipefail

# This script runs only during PostgreSQL first initialization, when the data
# directory is empty. PostgreSQL's official entrypoint will not re-run it for an
# existing volume. Change database names/users before the first startup, or
# apply later changes manually with a migration/backed-up maintenance window.

psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "${POSTGRES_DB}" \
  -v sub2api_user="${SUB2API_POSTGRES_USER}" \
  -v sub2api_password="${SUB2API_POSTGRES_PASSWORD}" \
  -v newapi_user="${NEW_API_POSTGRES_USER}" \
  -v newapi_password="${NEW_API_POSTGRES_PASSWORD}" <<-'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'sub2api_user', :'sub2api_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'sub2api_user')\gexec
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'newapi_user', :'newapi_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'newapi_user')\gexec
SQL

if ! psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" -tAc "SELECT 1 FROM pg_database WHERE datname='${SUB2API_POSTGRES_DB}'" | grep -q 1; then
  createdb --username "${POSTGRES_USER}" --owner "${SUB2API_POSTGRES_USER}" "${SUB2API_POSTGRES_DB}"
fi

if ! psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" -tAc "SELECT 1 FROM pg_database WHERE datname='${NEW_API_POSTGRES_DB}'" | grep -q 1; then
  createdb --username "${POSTGRES_USER}" --owner "${NEW_API_POSTGRES_USER}" "${NEW_API_POSTGRES_DB}"
fi

psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "${SUB2API_POSTGRES_DB}" \
  -v db="${SUB2API_POSTGRES_DB}" \
  -v app_user="${SUB2API_POSTGRES_USER}" <<-'SQL'
REVOKE ALL ON DATABASE :"db" FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE :"db" TO :"app_user";
GRANT ALL PRIVILEGES ON SCHEMA public TO :"app_user";
ALTER SCHEMA public OWNER TO :"app_user";
SQL

psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "${NEW_API_POSTGRES_DB}" \
  -v db="${NEW_API_POSTGRES_DB}" \
  -v app_user="${NEW_API_POSTGRES_USER}" <<-'SQL'
REVOKE ALL ON DATABASE :"db" FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE :"db" TO :"app_user";
GRANT ALL PRIVILEGES ON SCHEMA public TO :"app_user";
ALTER SCHEMA public OWNER TO :"app_user";
SQL
