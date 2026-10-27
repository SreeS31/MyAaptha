-- Read-only, aggregate-only review. A fixture-shaped name is a candidate, not
-- proof that an account is disposable. No account fields or identifiers leave SQL.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';
SELECT 'fixture_pattern_accounts' AS metric, COUNT(*) AS count
FROM users WHERE username ~ '^memory-[0-9a-f]{8}$'
UNION ALL
SELECT 'nominated_role_model_accounts', COUNT(DISTINCT trusted_user_id)
FROM trusted_people WHERE kind='ROLE_MODEL'
UNION ALL
SELECT 'fixture_pattern_nominated_role_models', COUNT(DISTINCT t.trusted_user_id)
FROM trusted_people t JOIN users u ON u.id=t.trusted_user_id
WHERE t.kind='ROLE_MODEL' AND u.username ~ '^memory-[0-9a-f]{8}$';
ROLLBACK;
