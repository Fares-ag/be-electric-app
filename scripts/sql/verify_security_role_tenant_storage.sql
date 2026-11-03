-- Verify 20260720160000_security_role_tenant_storage (read-only).
-- ./scripts/db.sh run scripts/sql/verify_security_role_tenant_storage.sql
--
-- Note: get_my_role() / is_true_admin() depend on auth.uid(); as postgres
-- they typically return NULL / false. Presence + policy text are the
-- authoritative apply checks here.

SELECT '1. RPCs present' AS section;
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'update_work_order_assignees',
    'upsert_work_order',
    'is_true_admin',
    'get_my_role',
    'insert_user',
    'update_user'
  )
ORDER BY 1;

SELECT '2. is_true_admin definition preview' AS section;
SELECT left(pg_get_functiondef(p.oid), 800) AS def_preview
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'is_true_admin';

SELECT '3. get_my_role definition preview (inactive → NULL)' AS section;
SELECT left(pg_get_functiondef(p.oid), 1200) AS def_preview
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_my_role';

SELECT '4. assets / companies RLS policies' AS section;
SELECT tablename, policyname, cmd, roles::text AS roles,
       left(COALESCE(qual::text, ''), 160) AS using_preview,
       left(COALESCE(with_check::text, ''), 160) AS with_check_preview
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('assets', 'companies')
ORDER BY 1, 2;

SELECT '5. BAD: assets/companies SELECT USING (true)' AS section;
SELECT tablename, policyname, qual::text AS using_expr
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('assets', 'companies')
  AND cmd = 'SELECT'
  AND qual::text IN ('true', '(true)');

SELECT '6. storage.objects INSERT / upload policies' AS section;
SELECT policyname, cmd,
       left(COALESCE(with_check::text, ''), 240) AS with_check_preview
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
    policyname ILIKE '%upload%'
    OR policyname ILIKE '%insert%'
    OR cmd = 'INSERT'
  )
ORDER BY 1;

SELECT '7. realtime publication tables' AS section;
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public'
ORDER BY 1;

SELECT '8. Function presence flags (apply gate)' AS section;
SELECT
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'is_true_admin'
  ) AS has_is_true_admin,
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_my_role'
  ) AS has_get_my_role,
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'assets'
      AND cmd = 'SELECT' AND qual::text IN ('true', '(true)')
  ) AS assets_still_open_select,
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects' AND cmd = 'INSERT'
      AND with_check::text LIKE '%work_orders/%'
  ) AS storage_has_path_prefix_check;
