-- Verify requestor read policies for Option A PM.
-- ./scripts/db.sh run scripts/sql/verify_requestor_pm_occurrences_read_rls.sql

SELECT 'pm_task_occurrences_table' AS check,
  CASE WHEN to_regclass('public.pm_task_occurrences') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'pm_schedules_table' AS check,
  CASE WHEN to_regclass('public.pm_schedules') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'requestor_pm_occurrences_read_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_task_occurrences'
  AND p.polname = 'Requestors read company pm_task_occurrences';

SELECT 'requestor_pm_schedules_read_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_schedules'
  AND p.polname = 'Requestors read company pm_schedules';

SELECT 'occurrence_count' AS check, count(*) AS total FROM pm_task_occurrences;

SELECT 'requestors_with_company' AS check, count(*) AS count
FROM users
WHERE role = 'requestor'
  AND "companyId" IS NOT NULL
  AND btrim("companyId") <> '';

-- Simulated visibility: occurrences on company assets per requestor tenant
SELECT 'occurrences_per_requestor_company' AS check,
  u.email,
  u."companyId",
  count(o.id) AS occurrence_count
FROM users u
LEFT JOIN assets a ON a."companyId" = u."companyId"
LEFT JOIN pm_task_occurrences o ON o."assetId" = a.id
WHERE u.role = 'requestor'
  AND u."companyId" IS NOT NULL
  AND btrim(u."companyId") <> ''
GROUP BY u.id, u.email, u."companyId"
ORDER BY occurrence_count DESC, u.email
LIMIT 10;
