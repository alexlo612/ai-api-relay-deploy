\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE legacy_names ON COMMIT DROP AS
SELECT key AS name
FROM jsonb_each_text(:'config'::jsonb -> 'legacy_aliases');

DO $$
BEGIN
    IF (SELECT count(*) FROM legacy_names) <> 3
       OR EXISTS (SELECT 1 FROM legacy_names
                  WHERE name NOT IN ('claude-fable', 'claude-opus', 'claude-sonnet')) THEN
        RAISE EXCEPTION 'Unexpected legacy aliases';
    END IF;
    IF (SELECT count(*) FROM channels
        WHERE (id = 6 AND name = 'sub2api-openai')
           OR (id = 8 AND name = 'sub2api-claude')) <> 2 THEN
        RAISE EXCEPTION 'Expected New API channels 6 and 8 are missing or changed';
    END IF;
END $$;

UPDATE channels c
SET models = (
        SELECT string_agg(trim(m.name), ',' ORDER BY m.ordinal)
        FROM unnest(string_to_array(coalesce(c.models, ''), ','))
             WITH ORDINALITY AS m(name, ordinal)
        WHERE trim(m.name) <> ''
          AND NOT EXISTS (SELECT 1 FROM legacy_names l WHERE l.name = trim(m.name))
    ),
    model_mapping = CASE
        WHEN coalesce(nullif(c.model_mapping, ''), '{}')::jsonb ?|
             ARRAY(SELECT name FROM legacy_names)
        THEN (coalesce(nullif(c.model_mapping, ''), '{}')::jsonb -
              ARRAY(SELECT name FROM legacy_names))::text
        ELSE c.model_mapping
    END,
    test_model = CASE WHEN EXISTS (SELECT 1 FROM legacy_names l WHERE l.name = c.test_model)
                      THEN '' ELSE c.test_model END
WHERE EXISTS (SELECT 1 FROM unnest(string_to_array(coalesce(c.models, ''), ',')) m
              JOIN legacy_names l ON l.name = trim(m))
   OR coalesce(nullif(c.model_mapping, ''), '{}')::jsonb ?|
      ARRAY(SELECT name FROM legacy_names)
   OR EXISTS (SELECT 1 FROM legacy_names l WHERE l.name = c.test_model);

DELETE FROM abilities a USING legacy_names l WHERE a.model = l.name;

UPDATE options o
SET value = (o.value::jsonb - ARRAY(SELECT name FROM legacy_names))::text
WHERE o.key IN ('ModelRatio', 'CompletionRatio', 'CacheRatio',
                'CreateCacheRatio', 'ImageRatio', 'AudioRatio',
                'AudioCompletionRatio', 'ModelPrice',
                'billing_setting.billing_mode', 'billing_setting.billing_expr')
  AND o.value::jsonb ?| ARRAY(SELECT name FROM legacy_names);

DELETE FROM models m USING legacy_names l WHERE m.model_name = l.name;

COMMIT;
