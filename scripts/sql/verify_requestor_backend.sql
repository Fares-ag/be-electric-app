-- Requestor app backend verification checklist (read-only)
-- ./scripts/db.sh run scripts/sql/verify_requestor_backend.sql
--
-- Companion: docs/REQUESTOR_DATABASE.md

-- =============================================================================
-- A. Authentication prerequisites
-- =============================================================================

SELECT 'requestor_users_exist' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status,
  count(*) AS count
FROM users WHERE role = 'requestor';

SELECT 'companies_exist' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status,
  count(*) AS count
FROM companies;

-- RPCs required for login (existence check)
SELECT 'rpc_get_user_by_email' AS check,
  CASE WHEN to_regprocedure('public.get_user_by_email(text)') IS NOT NULL
    THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'rpc_insert_user' AS check,
  CASE WHEN to_regprocedure('public.insert_user(jsonb)') IS NOT NULL
    THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'rpc_upsert_work_order' AS check,
  CASE WHEN to_regprocedure('public.upsert_work_order(jsonb)') IS NOT NULL
    THEN 'OK' ELSE 'MISSING' END AS status;

-- work_orders.id is text; RPC must not compare id to uuid (42883 on requestor submit)
SELECT 'rpc_upsert_work_order_text_id' AS check,
  CASE WHEN pg_get_functiondef(to_regprocedure('public.upsert_work_order(jsonb)'))
    NOT LIKE '%v_work_order_id uuid%'
    THEN 'OK' ELSE 'BROKEN — apply 20260706120000_fix_upsert_work_order_text_id.sql' END AS status;

-- =============================================================================
-- B. Create maintenance request — assets & chargers
-- =============================================================================

SELECT 'siemens_chargers' AS check, count(*) AS count
FROM assets WHERE manufacturer ILIKE '%siemens%';

SELECT 'kostad_chargers' AS check, count(*) AS count
FROM assets WHERE manufacturer ILIKE '%kostad%';

SELECT
  c.name AS company_name,
  count(a.id) FILTER (WHERE a.manufacturer ILIKE '%siemens%') AS siemens,
  count(a.id) FILTER (WHERE a.manufacturer ILIKE '%kostad%') AS kostad
FROM companies c
LEFT JOIN assets a ON a."companyId" = c.id
GROUP BY c.id, c.name
ORDER BY c.name
LIMIT 10;

-- =============================================================================
-- C–E. Work orders — RLS policies & recent rows
-- =============================================================================

SELECT 'work_orders_table' AS check,
  CASE WHEN to_regclass('public.work_orders') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'wo_requestor_select_policy' AS check,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'work_orders'
      AND policyname = 'Requestors can read own work orders'
  ) THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'wo_requestor_update_policy' AS check,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'work_orders'
      AND policyname = 'Requestors can update own work orders'
  ) THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'wo_realtime_enabled' AS check,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'work_orders'
  ) THEN 'OK' ELSE 'MISSING' END AS status;

SELECT id, "ticketNumber", status, "requestorId", "companyId", "createdAt"
FROM work_orders
ORDER BY "createdAt" DESC
LIMIT 5;

-- =============================================================================
-- F. Be Electric Support (delegates to verify_support_requests.sql sections)
-- =============================================================================

SELECT 'support_requests_table' AS check,
  CASE WHEN to_regclass('public.support_requests') IS NOT NULL THEN 'OK'
    ELSE 'MISSING — run ./scripts/db.sh migrate-support' END AS status;

SELECT 'support_createdBy_column' AS check,
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'support_requests' AND column_name = 'createdBy'
  ) THEN 'OK' ELSE 'LEGACY SCHEMA' END AS status;

SELECT 'support_requestor_insert_policy' AS check,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'support_requests'
      AND policyname = 'Requestors insert own support requests'
  ) THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'support_storage_insert_policy' AS check,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Authenticated upload support request attachments'
  ) THEN 'OK' ELSE 'MISSING' END AS status;

-- =============================================================================
-- G. Analytics — data availability
-- =============================================================================

SELECT 'work_orders_by_status' AS check, status, count(*) AS count
FROM work_orders
GROUP BY status
ORDER BY count DESC;

-- =============================================================================
-- H. Notifications — server table (app uses local prefs today)
-- =============================================================================

SELECT 'notifications_table' AS check,
  CASE WHEN to_regclass('public.notifications') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'notifications_select_policy' AS check,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'notifications' AND cmd = 'SELECT'
  ) THEN 'OK' ELSE 'MISSING' END AS status;

-- =============================================================================
-- J. Profile — company join sanity
-- =============================================================================

SELECT 'requestors_with_company' AS check,
  count(*) FILTER (WHERE u."companyId" IS NOT NULL) AS with_company,
  count(*) FILTER (WHERE u."companyId" IS NULL) AS without_company
FROM users u WHERE u.role = 'requestor';

-- =============================================================================
-- Storage bucket
-- =============================================================================

SELECT 'files_bucket' AS check,
  CASE WHEN EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'files') THEN 'OK'
    ELSE 'MISSING' END AS status;
