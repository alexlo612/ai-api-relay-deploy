\set ON_ERROR_STOP on
-- Temporary table shadows the live accounts table in this session.
CREATE TEMP TABLE accounts (id integer, name text, platform text, status text, credentials jsonb);
INSERT INTO accounts VALUES
    (1, 'codex-plan-plus-01', 'openai', 'active',
     '{"access_token":"untouched","model_mapping":{"claude-fable":"gpt-6-astra","claude-opus":"gpt-6-sol","claude-sonnet":"gpt-6-luna","gpt-6-sol":"gpt-6-sol"}}');

\ir ../scripts/model-bindings-sub2api-prune-legacy.sql

DO $$
BEGIN
    IF (SELECT credentials FROM accounts WHERE id = 1) <>
       '{"access_token":"untouched","model_mapping":{"gpt-6-sol":"gpt-6-sol"}}'::jsonb THEN
        RAISE EXCEPTION 'Sub2API legacy pruning altered unrelated credentials';
    END IF;
END $$;

\ir ../scripts/model-bindings-sub2api-prune-legacy.sql
\ir ../scripts/model-bindings-sub2api-legacy-check.sql
