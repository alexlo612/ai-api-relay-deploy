\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE legacy_mapping ON COMMIT DROP AS
SELECT key AS alias, value AS target
FROM jsonb_each_text(:'config'::jsonb -> 'legacy_aliases');

DO $$
BEGIN
    IF (SELECT count(*) FROM legacy_mapping) <> 3
       OR EXISTS (SELECT 1 FROM legacy_mapping
                  WHERE alias NOT IN ('claude-fable', 'claude-opus', 'claude-sonnet')) THEN
        RAISE EXCEPTION 'Unexpected legacy aliases';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM accounts
                   WHERE id = 1 AND name = 'codex-plan-plus-01'
                     AND platform = 'openai' AND status = 'active') THEN
        RAISE EXCEPTION 'Expected Sub2API OpenAI account is missing or changed';
    END IF;
    IF EXISTS (
        SELECT 1 FROM accounts a CROSS JOIN legacy_mapping l
        WHERE a.credentials->'model_mapping' ? l.alias
          AND (a.id <> 1 OR a.credentials->'model_mapping'->>l.alias <> l.target)
    ) THEN
        RAISE EXCEPTION 'Legacy mapping belongs to another account or has changed target';
    END IF;
END $$;

UPDATE accounts a
SET credentials = jsonb_set(
    a.credentials, '{model_mapping}',
    (a.credentials->'model_mapping') - ARRAY(SELECT alias FROM legacy_mapping)
)
WHERE a.id = 1
  AND a.credentials->'model_mapping' ?|
      ARRAY(SELECT alias FROM legacy_mapping);

COMMIT;
