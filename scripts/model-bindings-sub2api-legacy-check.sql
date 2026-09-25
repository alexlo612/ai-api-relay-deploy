\set ON_ERROR_STOP on
WITH plan AS (SELECT :'config'::jsonb -> 'legacy_aliases' AS names)
SELECT count(*)
FROM accounts a CROSS JOIN plan p
WHERE coalesce(a.credentials->'model_mapping', '{}') ?|
      ARRAY(SELECT key FROM jsonb_each(p.names));
