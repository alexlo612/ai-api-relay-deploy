\set ON_ERROR_STOP on
WITH plan AS (SELECT :'config'::jsonb AS doc),
bindings AS (SELECT key AS alias, value AS target
             FROM plan, jsonb_each_text(doc -> 'aliases')),
expected_channels AS (
    SELECT c.id,
           string_agg(DISTINCT m.model, ',' ORDER BY m.model) AS models,
           CASE WHEN c.id = 6 THEN
               coalesce(nullif(c.model_mapping, ''), '{}')::jsonb ||
               (SELECT jsonb_object_agg(alias, target) FROM bindings
                WHERE alias LIKE 'coding-%')
           ELSE coalesce(nullif(c.model_mapping, ''), '{}')::jsonb END AS mapping
    FROM channels c CROSS JOIN plan p
    CROSS JOIN LATERAL (
        SELECT trim(unnest(string_to_array(coalesce(c.models, ''), ','))) AS model
        UNION ALL
        SELECT alias FROM bindings
        WHERE (c.id = 6 AND alias LIKE 'coding-%')
           OR (c.id = 8 AND alias LIKE 'claude-%')
    ) m
    WHERE c.id IN (6, 8) AND m.model <> ''
      AND NOT (p.doc -> 'legacy_aliases' ? m.model)
      AND NOT (p.doc -> 'aliases' ? m.model
               AND ((c.id = 6 AND m.model LIKE 'claude-%')
                 OR (c.id = 8 AND m.model LIKE 'coding-%')))
    GROUP BY c.id, c.model_mapping
),
pricing AS (
    SELECT count(*) AS n FROM bindings b CROSS JOIN options o
    WHERE o.key IN (
        'ModelRatio', 'CompletionRatio', 'CacheRatio', 'CreateCacheRatio',
        'ImageRatio', 'AudioRatio', 'AudioCompletionRatio', 'ModelPrice',
        'billing_setting.billing_mode', 'billing_setting.billing_expr'
    ) AND (o.value::jsonb -> b.alias) IS DISTINCT FROM (o.value::jsonb -> b.target)
),
old_pricing AS (
    SELECT count(*) AS n FROM plan p CROSS JOIN options o
    WHERE o.key IN (
        'ModelRatio', 'CompletionRatio', 'CacheRatio', 'CreateCacheRatio',
        'ImageRatio', 'AudioRatio', 'AudioCompletionRatio', 'ModelPrice',
        'billing_setting.billing_mode', 'billing_setting.billing_expr'
    ) AND o.value::jsonb ?| ARRAY(SELECT key FROM jsonb_each_text(p.doc -> 'legacy_aliases'))
),
channels_diff AS (
    SELECT count(*) AS n FROM channels c JOIN expected_channels e ON c.id = e.id
    WHERE c.models <> e.models
       OR coalesce(nullif(c.model_mapping, ''), '{}')::jsonb <> e.mapping
       OR c.status <> 1
       OR (c.id = 8 AND EXISTS (
           SELECT 1 FROM bindings b WHERE b.alias LIKE 'claude-%'
             AND coalesce(nullif(c.model_mapping, ''), '{}')::jsonb ? b.alias))
       OR (c.id = 8 AND c.test_model IS DISTINCT FROM 'claude-opus-5-5')
),
abilities_diff AS (
    SELECT count(*) AS n FROM channels c CROSS JOIN bindings b
    WHERE ((c.id = 6 AND b.alias LIKE 'coding-%')
        OR (c.id = 8 AND b.alias LIKE 'claude-%'))
      AND NOT EXISTS (
          SELECT 1 FROM abilities a WHERE a.channel_id = c.id
            AND a.model = b.alias AND a."group" = c."group" AND a.enabled
      )
), old_abilities AS (
    SELECT count(*) AS n FROM abilities a CROSS JOIN plan p
    WHERE a.channel_id IN (6, 8)
      AND (p.doc -> 'legacy_aliases' ? a.model
        OR (a.channel_id = 6 AND a.model LIKE 'claude-%'
            AND p.doc -> 'aliases' ? a.model)
        OR (a.channel_id = 8 AND a.model LIKE 'coding-%'
            AND p.doc -> 'aliases' ? a.model))
)
SELECT pricing.n + old_pricing.n + channels_diff.n + abilities_diff.n + old_abilities.n
FROM pricing, old_pricing, channels_diff, abilities_diff, old_abilities;
