\set ON_ERROR_STOP on
-- Temporary tables shadow production tables for the duration of this session.
CREATE TEMP TABLE channels (id integer, name text, models text, model_mapping text, test_model text);
CREATE TEMP TABLE abilities (channel_id integer, model text);
CREATE TEMP TABLE models (model_name text, deleted_at bigint);
CREATE TEMP TABLE options (key text, value text);

INSERT INTO channels VALUES
    (6, 'sub2api-openai',
     'coding-fast,claude-fable,gpt-6-sol,claude-opus,claude-sonnet',
     '{"coding-fast":"gpt-6-luna","claude-fable":"gpt-6-astra"}', 'claude-opus'),
    (8, 'sub2api-claude',
     'claude-sonnet-5,claude-opus-5-5,claude-fable-5-1', '', 'claude-opus-5-5');
INSERT INTO abilities VALUES (6, 'claude-fable'), (6, 'claude-opus'),
                            (8, 'claude-sonnet'), (8, 'claude-opus-5-5');
INSERT INTO models VALUES ('claude-fable', NULL), ('claude-opus-5-5', NULL);
INSERT INTO options VALUES
    ('billing_setting.billing_expr',
     '{"claude-fable":"old","claude-opus-5-5":"custom tiered_expr"}'),
    ('ModelRatio', '{"claude-sonnet":1,"coding-fast":2}');

\ir ../scripts/model-bindings-newapi-prune-legacy.sql

DO $$
BEGIN
    IF (SELECT models FROM channels WHERE id = 6) <> 'coding-fast,gpt-6-sol'
       OR (SELECT models FROM channels WHERE id = 8) <>
          'claude-sonnet-5,claude-opus-5-5,claude-fable-5-1'
       OR (SELECT model_mapping::jsonb FROM channels WHERE id = 6) <>
          '{"coding-fast":"gpt-6-luna"}'::jsonb
       OR (SELECT test_model FROM channels WHERE id = 6) <> ''
       OR (SELECT test_model FROM channels WHERE id = 8) <> 'claude-opus-5-5'
       OR (SELECT count(*) FROM abilities) <> 1
       OR (SELECT count(*) FROM models) <> 1
       OR (SELECT value::jsonb FROM options WHERE key = 'billing_setting.billing_expr') <>
          '{"claude-opus-5-5":"custom tiered_expr"}'::jsonb
       OR (SELECT value::jsonb FROM options WHERE key = 'ModelRatio') <>
          '{"coding-fast":2}'::jsonb THEN
        RAISE EXCEPTION 'Legacy pruning changed unrelated data or kept a legacy alias';
    END IF;
END $$;

\ir ../scripts/model-bindings-newapi-prune-legacy.sql
\ir ../scripts/model-bindings-newapi-legacy-check.sql

DO $$
BEGIN
    IF (SELECT count(*) FROM abilities) <> 1
       OR (SELECT models FROM channels WHERE id = 6) <> 'coding-fast,gpt-6-sol' THEN
        RAISE EXCEPTION 'Legacy pruning is not idempotent';
    END IF;
END $$;
