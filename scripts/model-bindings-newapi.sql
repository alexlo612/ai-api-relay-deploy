\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE model_plan AS SELECT :'config'::jsonb AS doc;
CREATE TEMP TABLE desired_model_bindings ON COMMIT DROP AS
SELECT key AS alias, value AS target
FROM model_plan, jsonb_each_text(doc -> 'aliases');

DO $$
BEGIN
    IF (SELECT count(*) FROM desired_model_bindings) <> 6 THEN
        RAISE EXCEPTION 'Expected six model aliases';
    END IF;
    IF (SELECT count(*) FROM channels
        WHERE (id = 6 AND name = 'sub2api-openai' AND type = 1 AND status = 1)
           OR (id = 8 AND name = 'sub2api-claude' AND type = 14 AND status = 1)) <> 2 THEN
        RAISE EXCEPTION 'Expected New API channels 6 and 8 are missing or changed';
    END IF;
    IF EXISTS (
        SELECT 1 FROM desired_model_bindings b
        CROSS JOIN (VALUES ('ModelRatio'), ('CompletionRatio'),
                           ('billing_setting.billing_mode'),
                           ('billing_setting.billing_expr')) AS required(key)
        LEFT JOIN options o ON o.key = required.key
        WHERE o.key IS NULL OR NOT (o.value::jsonb ? b.target)
    ) THEN
        RAISE EXCEPTION 'A GPT-6 target is missing required pricing settings';
    END IF;
    IF EXISTS (
        SELECT 1 FROM desired_model_bindings b
        JOIN options o ON o.key = 'ModelPrice'
        WHERE o.value::jsonb ? b.target
    ) THEN
        RAISE EXCEPTION 'A GPT-6 target has a fixed price; review billing mode first';
    END IF;
    IF EXISTS (
        SELECT 1 FROM desired_model_bindings b
        CROSS JOIN (VALUES ('billing_setting.billing_mode'),
                           ('billing_setting.billing_expr')) AS required(key)
        LEFT JOIN options o ON o.key = required.key
        WHERE b.alias LIKE 'claude-%'
          AND (o.key IS NULL OR NOT (o.value::jsonb ? b.alias))
    ) THEN
        RAISE EXCEPTION 'Configure explicit Claude alias billing before applying';
    END IF;
    IF EXISTS (
        SELECT 1 FROM channels c, model_plan p,
             jsonb_each_text(p.doc -> 'aliases') b
        WHERE c.id NOT IN (6, 8)
          AND b.key = ANY(string_to_array(c.models, ','))
    ) THEN
        RAISE EXCEPTION 'A desired alias already exists in another channel';
    END IF;
    IF EXISTS (
        SELECT 1 FROM channels c, model_plan p,
             jsonb_each_text(p.doc -> 'legacy_aliases') b
        WHERE c.id NOT IN (6, 8)
          AND b.key = ANY(string_to_array(c.models, ','))
    ) THEN
        RAISE EXCEPTION 'A legacy alias is still used by another channel';
    END IF;
    IF EXISTS (
        SELECT 1 FROM channels c, model_plan p,
             jsonb_each_text(p.doc -> 'aliases') b
        WHERE c.id = 8 AND b.key LIKE 'claude-%'
          AND coalesce(nullif(c.model_mapping, ''), '{}')::jsonb ? b.key
    ) THEN
        RAISE EXCEPTION 'Claude channel must leave versioned aliases unmapped for Sub2API';
    END IF;
    IF EXISTS (
        SELECT 1 FROM channels c, model_plan p,
             jsonb_each_text(p.doc -> 'aliases') b
        WHERE c.id = 6 AND b.key LIKE 'coding-%'
          AND coalesce(nullif(c.model_mapping, ''), '{}')::jsonb ? b.key
          AND coalesce(nullif(c.model_mapping, ''), '{}')::jsonb ->> b.key <> b.value
    ) THEN
        RAISE EXCEPTION 'An OpenAI channel model mapping conflicts with the desired target';
    END IF;
    IF EXISTS (
        SELECT 1 FROM models m JOIN desired_model_bindings b ON m.model_name = b.alias
        WHERE b.alias LIKE 'coding-%' AND m.deleted_at IS NULL
          AND (m.name_rule <> 0 OR (coalesce(nullif(m.endpoints, ''), '{}')::jsonb ? 'anthropic'
               AND coalesce(nullif(m.endpoints, ''), '{}')::jsonb -> 'anthropic'
                   <> '{"path":"/v1/messages","method":"POST"}'::jsonb))
    ) THEN
        RAISE EXCEPTION 'A coding model metadata rule or Anthropic endpoint differs from the expected value';
    END IF;
END $$;

WITH replacements AS (
    SELECT o.key,
           (o.value::jsonb - ARRAY(SELECT key FROM model_plan,
                                    jsonb_each_text(doc -> 'legacy_aliases'))
                            - ARRAY(SELECT alias FROM desired_model_bindings
                                    WHERE alias LIKE 'coding-%'))
           || COALESCE((
               SELECT jsonb_object_agg(b.alias, o.value::jsonb -> b.target)
               FROM desired_model_bindings b
               WHERE b.alias LIKE 'coding-%' AND o.value::jsonb ? b.target
           ), '{}'::jsonb) AS new_value
    FROM options o
    WHERE o.key IN (
        'ModelRatio', 'CompletionRatio', 'CacheRatio', 'CreateCacheRatio',
        'ImageRatio', 'AudioRatio', 'AudioCompletionRatio', 'ModelPrice',
        'billing_setting.billing_mode', 'billing_setting.billing_expr'
    )
)
UPDATE options o
SET value = r.new_value::text
FROM replacements r
WHERE o.key = r.key AND o.value::jsonb IS DISTINCT FROM r.new_value;

UPDATE channels c
SET models = desired.models,
    model_mapping = CASE WHEN c.id = 6 THEN
        (coalesce(nullif(c.model_mapping, ''), '{}')::jsonb ||
         (SELECT jsonb_object_agg(b.alias, b.target)
          FROM desired_model_bindings b WHERE b.alias LIKE 'coding-%'))::text
        ELSE c.model_mapping END,
    test_model = CASE WHEN c.id = 8 THEN 'claude-opus-5-5'
                      ELSE c.test_model END
FROM (
    SELECT c2.id, string_agg(DISTINCT m.model, ',' ORDER BY m.model) AS models
    FROM channels c2 CROSS JOIN model_plan p
    CROSS JOIN LATERAL (
        SELECT trim(unnest(string_to_array(coalesce(c2.models, ''), ','))) AS model
        UNION ALL
        SELECT b.alias FROM desired_model_bindings b
        WHERE (c2.id = 6 AND b.alias LIKE 'coding-%')
           OR (c2.id = 8 AND b.alias LIKE 'claude-%')
    ) m
    WHERE c2.id IN (6, 8) AND m.model <> ''
      AND NOT (p.doc -> 'legacy_aliases' ? m.model)
      AND NOT (p.doc -> 'aliases' ? m.model
               AND ((c2.id = 6 AND m.model LIKE 'claude-%')
                 OR (c2.id = 8 AND m.model LIKE 'coding-%')))
    GROUP BY c2.id
) desired
WHERE c.id = desired.id;

DELETE FROM abilities a USING model_plan p
WHERE a.channel_id IN (6, 8)
  AND (p.doc -> 'aliases' ? a.model OR p.doc -> 'legacy_aliases' ? a.model);

INSERT INTO abilities ("group", model, channel_id, enabled, priority, weight, tag)
SELECT c."group", b.alias, c.id, true, c.priority, c.weight, c.tag
FROM channels c CROSS JOIN desired_model_bindings b
WHERE (c.id = 6 AND b.alias LIKE 'coding-%')
   OR (c.id = 8 AND b.alias LIKE 'claude-%');

INSERT INTO models (model_name, endpoints, status, sync_official,
                    created_time, updated_time, name_rule)
SELECT b.alias, '{"anthropic":{"path":"/v1/messages","method":"POST"}}',
       1, 0, extract(epoch FROM now())::bigint, extract(epoch FROM now())::bigint, 0
FROM desired_model_bindings b
WHERE b.alias LIKE 'coding-%'
  AND NOT EXISTS (SELECT 1 FROM models m
                  WHERE m.model_name = b.alias AND m.deleted_at IS NULL);

UPDATE models m
SET endpoints = (coalesce(nullif(m.endpoints, ''), '{}')::jsonb ||
                '{"anthropic":{"path":"/v1/messages","method":"POST"}}'::jsonb)::text,
    updated_time = extract(epoch FROM now())::bigint
FROM desired_model_bindings b
WHERE m.model_name = b.alias AND b.alias LIKE 'coding-%' AND m.deleted_at IS NULL
  AND NOT (coalesce(nullif(m.endpoints, ''), '{}')::jsonb ? 'anthropic');

DELETE FROM models m USING model_plan p
WHERE m.deleted_at IS NULL AND m.name_rule = 0
  AND p.doc -> 'legacy_aliases' ? m.model_name;

COMMIT;
