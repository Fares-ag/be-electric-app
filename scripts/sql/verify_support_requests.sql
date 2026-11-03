-- Verify Be Electric support_requests backend is ready for the requestor app.
-- ./scripts/db.sh run scripts/sql/verify_support_requests.sql

-- 1. Table exists
SELECT
  'support_requests_table' AS check,
  CASE
    WHEN to_regclass('public.support_requests') IS NOT NULL THEN 'OK'
    ELSE 'MISSING — run scripts/sql/migrate_support_requests.sql'
  END AS status;

-- 2. Required columns (camelCase)
SELECT
  'support_requests_columns' AS check,
  CASE
    WHEN count(*) FILTER (WHERE column_name IN (
      'id', 'type', 'status', 'summary', 'topic', 'question', 'details',
      'chargerModel', 'chargerSerialNumber', 'address', 'country',
      'scheduledDate', 'attachments', 'createdBy', 'createdAt', 'companyId',
      'staffReply'
    )) = 17 THEN 'OK'
    ELSE 'INCOMPLETE'
  END AS status
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'support_requests';

-- 3. RLS enabled
SELECT
  'support_requests_rls' AS check,
  CASE
    WHEN to_regclass('public.support_requests') IS NULL THEN 'MISSING TABLE'
    WHEN (
      SELECT c.relrowsecurity
      FROM pg_class c
      WHERE c.oid = to_regclass('public.support_requests')
    ) THEN 'OK'
    ELSE 'DISABLED'
  END AS status;

-- 4. Requestor policies
SELECT
  'requestor_insert_policy' AS check,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'support_requests'
        AND policyname = 'Requestors insert own support requests'
        AND cmd = 'INSERT'
    ) THEN 'OK'
    ELSE 'MISSING'
  END AS status;

SELECT
  'requestor_select_policy' AS check,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'support_requests'
        AND policyname = 'Requestors read own support requests'
        AND cmd = 'SELECT'
    ) THEN 'OK'
    ELSE 'MISSING'
  END AS status;

-- 5. Admin policy (optional — needs get_my_role())
SELECT
  'admin_manage_policy' AS check,
  CASE
    WHEN to_regprocedure('public.get_my_role()') IS NULL THEN 'SKIPPED (no get_my_role)'
    WHEN EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'support_requests'
        AND policyname = 'Admins manage support_requests'
    ) THEN 'OK'
    ELSE 'MISSING'
  END AS status;

-- 6. Storage upload policies
SELECT
  'storage_insert_policy' AS check,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'storage'
        AND tablename = 'objects'
        AND policyname = 'Authenticated upload support request attachments'
    ) THEN 'OK'
    ELSE 'MISSING'
  END AS status;

SELECT
  'storage_update_policy' AS check,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'storage'
        AND tablename = 'objects'
        AND policyname = 'Authenticated update support request attachments'
    ) THEN 'OK'
    ELSE 'MISSING'
  END AS status;

-- 7. files bucket exists
SELECT
  'files_bucket' AS check,
  CASE
    WHEN EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'files') THEN 'OK'
    ELSE 'MISSING'
  END AS status;

-- 8. Recent rows (informational — requires table from migrate)
SELECT
  id,
  type,
  status,
  "createdBy",
  "createdAt",
  CASE WHEN "staffReply" IS NULL THEN '—' ELSE 'set' END AS staff_reply
FROM public.support_requests
ORDER BY "createdAt" DESC
LIMIT 10;
