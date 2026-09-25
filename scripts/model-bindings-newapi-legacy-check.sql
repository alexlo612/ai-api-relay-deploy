\set ON_ERROR_STOP on
WITH plan AS (SELECT :'config'::jsonb -> 'legacy_aliases' AS names)
SELECT
    (SELECT count(*) FROM channels c CROSS JOIN plan p
     WHERE EXISTS (SELECT 1 FROM unnest(string_to_array(coalesce(c.models, ''), ',')) m
                   WHERE p.names ? trim(m))
        OR coalesce(nullif(c.model_mapping, ''), '{}')::jsonb ?|
           ARRAY(SELECT key FROM jsonb_each(p.names))
        OR p.names ? coalesce(c.test_model, ''))
  + (SELECT count(*) FROM abilities a CROSS JOIN plan p WHERE p.names ? a.model)
  + (SELECT count(*) FROM models m CROSS JOIN plan p
     WHERE p.names ? m.model_name AND m.deleted_at IS NULL)
  + (SELECT count(*) FROM options o CROSS JOIN plan p
     WHERE o.key IN ('ModelRatio', 'CompletionRatio', 'CacheRatio',
                     'CreateCacheRatio', 'ImageRatio', 'AudioRatio',
                     'AudioCompletionRatio', 'ModelPrice',
                     'billing_setting.billing_mode', 'billing_setting.billing_expr')
       AND o.value::jsonb ?| ARRAY(SELECT key FROM jsonb_each(p.names)));
