-- Requestor PPM (pm_tasks) backend verification checklist (read-only)
-- ./scripts/db.sh run scripts/sql/verify_requestor_ppm_backend.sql
--
-- Companion: docs/requestor-db/12-ppm-preventive-maintenance.md
-- Audit: docs/QA_REQUESTOR_PPM_ENTERPRISE_AUDIT.md

-- =============================================================================
-- A. Table & RLS baseline
-- =============================================================================

SELECT 'pm_tasks_table' AS check,
  CASE WHEN to_regclass('public.pm_tasks') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'pm_tasks_rls_enabled' AS check,
  CASE WHEN relrowsecurity THEN 'OK' ELSE 'DISABLED' END AS status
FROM pg_class
WHERE relname = 'pm_tasks';

SELECT 'pm_tasks_row_count' AS check, count(*) AS total,
  count(*) FILTER (WHERE COALESCE(array_length("assignedTechnicianIds", 1), 0) = 0) AS unassigned
FROM pm_tasks;

-- =============================================================================
-- B. Policies relevant to requestor vs technician vs admin
-- =============================================================================

SELECT 'pm_admin_manage_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_tasks'
  AND p.polname = 'Admins can manage pm_tasks';

SELECT 'pm_technician_read_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_tasks'
  AND p.polname = 'Technicians can read assigned pm_tasks';

SELECT 'pm_technician_update_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_tasks'
  AND p.polname = 'Technicians can update assigned pm_tasks';

SELECT 'pm_requestor_read_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status,
  count(*) AS policy_count
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_tasks'
  AND p.polcmd = 'r'
  AND (
    p.polname ILIKE '%requestor%'
    OR pg_get_expr(p.polqual, p.polrelid) ILIKE '%get_my_role%requestor%'
    OR pg_get_expr(p.polqual, p.polrelid) ILIKE '%companyId%'
  );

-- Expected today: MISSING (no requestor SELECT on pm_tasks)

-- =============================================================================
-- C. Company / asset linkage for future requestor read-only PPM
-- =============================================================================

SELECT 'pm_tasks_with_asset' AS check,
  count(*) FILTER (WHERE "assetId" IS NOT NULL AND "assetId" <> '') AS with_asset,
  count(*) FILTER (WHERE "assetId" IS NULL OR "assetId" = '') AS without_asset
FROM pm_tasks;

SELECT 'pm_tasks_join_assets_sample' AS check,
  pt.id,
  pt."taskName",
  pt.status,
  pt."assetId",
  a."companyId" AS asset_company
FROM pm_tasks pt
LEFT JOIN assets a ON a.id = pt."assetId"
LIMIT 10;

SELECT 'requestor_users_with_company' AS check, count(*) AS count
FROM users
WHERE role = 'requestor' AND "companyId" IS NOT NULL AND "companyId" <> '';

-- =============================================================================
-- D. Cross-check: would company-scoped read return rows for any requestor?
-- (Simulates Option B RLS — informational only, not enforced)
-- =============================================================================

SELECT 'ppm_visible_if_company_scoped' AS check,
  u.email AS requestor_email,
  u."companyId",
  count(pt.id) AS pm_tasks_on_company_assets
FROM users u
LEFT JOIN assets a ON a."companyId" = u."companyId"
LEFT JOIN pm_tasks pt ON pt."assetId" = a.id
WHERE u.role = 'requestor'
GROUP BY u.id, u.email, u."companyId"
ORDER BY pm_tasks_on_company_assets DESC, u.email
LIMIT 10;

-- =============================================================================
-- E. Notifications table (PM-related types exist; requestor UI local-only)
-- =============================================================================

SELECT 'notifications_pm_related' AS check, count(*) AS count
FROM notifications
WHERE type ILIKE '%pm%' OR "relatedType" = 'pm_task';
