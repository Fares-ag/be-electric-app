-- App Store / reviewer readiness checks (read-only)
-- ./scripts/db.sh run scripts/sql/app_review_checklist.sql

-- Requestor users
SELECT 'requestor_users' AS check, count(*) AS count
FROM users WHERE role = 'requestor';

-- Companies
SELECT 'companies' AS check, count(*) AS count FROM companies;

-- Siemens chargers
SELECT 'siemens_chargers' AS check, count(*) AS count
FROM assets WHERE manufacturer ILIKE '%siemens%';

-- Kostad chargers
SELECT 'kostad_chargers' AS check, count(*) AS count
FROM assets WHERE manufacturer ILIKE '%kostad%';

-- Companies missing chargers (requestor flow will fail)
SELECT
  c.id AS company_id,
  c.name AS company_name,
  count(a.id) FILTER (WHERE a.manufacturer ILIKE '%siemens%') AS siemens_count,
  count(a.id) FILTER (WHERE a.manufacturer ILIKE '%kostad%') AS kostad_count
FROM companies c
LEFT JOIN assets a ON a.companyId = c.id
GROUP BY c.id, c.name
ORDER BY c.name
LIMIT 25;

-- Realtime enabled on work_orders (needs replication slot)
SELECT
  schemaname,
  tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename = 'work_orders';

-- Be Electric Support (Know How / Commissioning)
SELECT
  'support_requests_table' AS check,
  CASE
    WHEN to_regclass('public.support_requests') IS NOT NULL THEN 'OK'
    ELSE 'MISSING — run ./scripts/db.sh migrate-support'
  END AS status;
