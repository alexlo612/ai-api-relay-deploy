\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE desired_model_bindings (
    alias text PRIMARY KEY,
    target text NOT NULL
) ON COMMIT DROP;

INSERT INTO desired_model_bindings (alias, target)
SELECT key, value FROM jsonb_each_text(:'bindings'::jsonb);

DO $$
BEGIN
    IF (SELECT count(*) FROM desired_model_bindings) <> 3 THEN
        RAISE EXCEPTION 'Expected exactly three Claude Code model aliases';
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
        JOIN options o ON o.key IN (
            'ModelRatio', 'CompletionRatio', 'CacheRatio', 'CreateCacheRatio',
            'ImageRatio', 'AudioRatio', 'AudioCompletionRatio', 'ModelPrice',
            'billing_setting.billing_mode', 'billing_setting.billing_expr'
        )
        WHERE o.value::jsonb ? b.alias
          AND (o.value::jsonb -> b.alias) IS DISTINCT FROM (o.value::jsonb -> b.target)
    ) THEN
        RAISE EXCEPTION 'An alias already has conflicting pricing; review it before applying';
    END IF;
END $$;

WITH replacements AS (
    SELECT o.key,
           (o.value::jsonb - ARRAY(SELECT alias FROM desired_model_bindings))
           || COALESCE((
               SELECT jsonb_object_agg(b.alias, o.value::jsonb -> b.target)
               FROM desired_model_bindings b
               WHERE o.value::jsonb ? b.target
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

COMMIT;
