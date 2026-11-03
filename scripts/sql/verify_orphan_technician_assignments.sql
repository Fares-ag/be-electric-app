-- Verify T-003: orphan technician assignments prevention
-- ./scripts/db.sh verify-orphan-assignments

-- Existing orphan data (report-only — migration does not auto-fix)
SELECT 'wo_orphan_technician_ids' AS check,
  CASE WHEN count(*) = 0 THEN 'OK' ELSE 'DATA_ISSUE' END AS status,
  count(DISTINCT wo.id) AS affected_work_orders
FROM work_orders wo
WHERE EXISTS (
  SELECT 1
  FROM unnest(COALESCE(wo."assignedTechnicianIds", ARRAY[]::text[])) tid
  WHERE tid <> '' AND NOT EXISTS (SELECT 1 FROM users u WHERE u.id = tid)
);

SELECT 'pm_orphan_technician_ids' AS check,
  CASE WHEN count(*) = 0 THEN 'OK' ELSE 'DATA_ISSUE' END AS status,
  count(DISTINCT pt.id) AS affected_pm_tasks
FROM pm_tasks pt
WHERE EXISTS (
  SELECT 1
  FROM unnest(COALESCE(pt."assignedTechnicianIds", ARRAY[]::text[])) tid
  WHERE tid <> '' AND NOT EXISTS (SELECT 1 FROM users u WHERE u.id = tid)
);

-- Prevention objects deployed
SELECT 'fn_scrub_user_from_technician_assignments' AS check,
  CASE WHEN to_regprocedure('public.scrub_user_from_technician_assignments(text)') IS NOT NULL
    THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'fn_delete_user_by_id' AS check,
  CASE WHEN to_regprocedure('public.delete_user_by_id(text)') IS NOT NULL
    THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'delete_user_scrubs_assignments' AS check,
  CASE WHEN pg_get_functiondef(p.oid) ILIKE '%scrub_user_from_technician_assignments%'
    THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'delete_user_by_id' AND n.nspname = 'public'
LIMIT 1;

SELECT 'trg_validate_work_orders_assigned_technicians' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE c.relname = 'work_orders'
  AND NOT t.tgisinternal
  AND t.tgname = 'trg_validate_work_orders_assigned_technicians';

SELECT 'trg_validate_pm_tasks_assigned_technicians' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE c.relname = 'pm_tasks'
  AND NOT t.tgisinternal
  AND t.tgname = 'trg_validate_pm_tasks_assigned_technicians';

SELECT 'fn_validate_assigned_technician_ids' AS check,
  CASE WHEN to_regprocedure('public.validate_assigned_technician_ids()') IS NOT NULL
    THEN 'OK' ELSE 'MISSING' END AS status;
