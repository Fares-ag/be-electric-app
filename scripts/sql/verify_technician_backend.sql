-- Technician app backend verification checklist (read-only)
-- ./scripts/db.sh run scripts/sql/verify_technician_backend.sql
--
-- Companion: docs/technician-db/TECHNICIAN_DATABASE.md

-- =============================================================================
-- A. Authentication & users
-- =============================================================================

SELECT 'technician_users_exist' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status,
  count(*) AS count
FROM users WHERE role = 'technician';

SELECT 'manager_admin_users_exist' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status,
  count(*) AS count
FROM users WHERE role IN ('manager', 'admin');

SELECT 'auth_users_aligned' AS check,
  CASE WHEN count(*) = 0 THEN 'OK' ELSE 'MISMATCH' END AS status,
  count(*) AS orphan_auth_users
FROM auth.users au
LEFT JOIN public.users u ON u.id = au.id::text
WHERE u.id IS NULL;

SELECT 'rpc_get_user_by_email' AS check,
  CASE WHEN to_regprocedure('public.get_user_by_email(text)') IS NOT NULL
    THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'rpc_insert_user' AS check,
  CASE WHEN to_regprocedure('public.insert_user(jsonb)') IS NOT NULL
    THEN 'OK' ELSE 'MISSING' END AS status;

SELECT 'fn_get_my_role' AS check,
  CASE WHEN to_regprocedure('public.get_my_role()') IS NOT NULL
    THEN 'OK' ELSE 'MISSING' END AS status;

-- =============================================================================
-- B. Work orders — assignment & orphan IDs
-- =============================================================================

SELECT 'work_orders_assigned' AS check, count(*) AS count
FROM work_orders
WHERE COALESCE(array_length("assignedTechnicianIds", 1), 0) > 0;

SELECT 'wo_orphan_technician_ids' AS check,
  CASE WHEN count(*) = 0 THEN 'OK' ELSE 'DATA_ISSUE' END AS status,
  count(*) AS affected_rows
FROM work_orders wo
WHERE EXISTS (
  SELECT 1
  FROM unnest(COALESCE(wo."assignedTechnicianIds", ARRAY[]::text[])) tid
  WHERE tid <> '' AND NOT EXISTS (SELECT 1 FROM users u WHERE u.id = tid)
);

-- T-003 prevention (see verify_orphan_technician_assignments.sql)
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

SELECT 'wo_technician_read_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'work_orders'
  AND p.polname ILIKE '%technician%read%';

SELECT 'wo_technician_update_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'work_orders'
  AND p.polname ILIKE '%technician%update%';

-- =============================================================================
-- C. PM tasks — critical for technician completion
-- =============================================================================

SELECT 'pm_tasks_assigned' AS check, count(*) AS count
FROM pm_tasks
WHERE COALESCE(array_length("assignedTechnicianIds", 1), 0) > 0;

SELECT 'pm_technician_read_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_tasks'
  AND p.polname ILIKE '%technician%read%';

SELECT 'pm_technician_update_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING — run ./scripts/db.sh migrate-pm-tasks-technician-update' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'pm_tasks'
  AND p.polname = 'Technicians can update assigned pm_tasks'
  AND p.polcmd = 'w';

-- =============================================================================
-- D. Parts requests & inventory
-- =============================================================================

SELECT 'parts_requests_rows' AS check, count(*) AS count FROM parts_requests;

SELECT 'parts_request_insert_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'parts_requests'
  AND p.polcmd = 'a';

SELECT 'inventory_technician_read_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING — run ./scripts/db.sh migrate-inventory-technician-select' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'inventory_items'
  AND p.polname = 'Technicians can read inventory'
  AND p.polcmd = 'r';

SELECT 'inventory_items_rows' AS check, count(*) AS count FROM inventory_items;

-- =============================================================================
-- E. Assets & storage
-- =============================================================================

SELECT 'assets_readable' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'assets'
  AND p.polcmd = 'r';

SELECT 'storage_files_select' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'storage' AND c.relname = 'objects'
  AND p.polname ILIKE '%files%select%';

SELECT 'storage_files_insert' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'storage' AND c.relname = 'objects'
  AND p.polname ILIKE '%files%insert%';

-- =============================================================================
-- F. Notifications
-- =============================================================================

SELECT 'notifications_select_own' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'notifications'
  AND p.polcmd = 'r';

-- =============================================================================
-- G. Sample technician visibility (replace email for your test account)
-- =============================================================================

-- Uncomment and set email to verify a specific technician sees assigned WOs:
-- SELECT wo.id, wo."ticketNumber", wo.status, wo."assignedTechnicianIds"
-- FROM work_orders wo
-- JOIN users u ON u.id = ANY(COALESCE(wo."assignedTechnicianIds", ARRAY[]::text[]))
-- WHERE u.email = 'fares@gmail.com'
-- LIMIT 10;
