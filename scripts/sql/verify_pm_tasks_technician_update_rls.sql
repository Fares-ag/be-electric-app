-- Verify T-001: pm_tasks technician UPDATE RLS
-- ./scripts/db.sh verify-pm-tasks-technician-update

SELECT 'pm_tasks_rls_enabled' AS check,
  CASE WHEN relrowsecurity THEN 'OK' ELSE 'DISABLED' END AS status
FROM pg_class
WHERE relname = 'pm_tasks';

SELECT 'pm_technician_update_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status,
  count(*) AS policy_count
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_tasks'
  AND p.polname = 'Technicians can update assigned pm_tasks'
  AND p.polcmd = 'w';

SELECT 'pm_admin_manage_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_tasks'
  AND p.polname = 'Admins can manage pm_tasks';

SELECT polname,
  pg_get_expr(polqual, p.polrelid) AS using_expr,
  pg_get_expr(polwithcheck, p.polrelid) AS with_check
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_tasks'
  AND p.polname = 'Technicians can update assigned pm_tasks';
