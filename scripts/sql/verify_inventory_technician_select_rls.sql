-- Verify T-002: inventory_items technician SELECT RLS
-- ./scripts/db.sh verify-inventory-technician-select

SELECT 'inventory_rls_enabled' AS check,
  CASE WHEN relrowsecurity THEN 'OK' ELSE 'DISABLED' END AS status
FROM pg_class
WHERE relname = 'inventory_items';

SELECT 'inventory_technician_read_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status,
  count(*) AS policy_count
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'inventory_items'
  AND p.polname = 'Technicians can read inventory'
  AND p.polcmd = 'r';

SELECT 'inventory_admin_manage_policy' AS check,
  CASE WHEN count(*) > 0 THEN 'OK' ELSE 'MISSING' END AS status
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'inventory_items'
  AND p.polname = 'Admins manage inventory';

SELECT 'inventory_technician_write_policies' AS check,
  CASE WHEN count(*) = 0 THEN 'OK' ELSE 'UNEXPECTED' END AS status,
  count(*) AS write_policy_count
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'inventory_items'
  AND p.polcmd IN ('a', 'w', 'd')
  AND (
    pg_get_expr(polqual, p.polrelid) ILIKE '%technician%'
    OR pg_get_expr(polwithcheck, p.polrelid) ILIKE '%technician%'
  );

SELECT polname,
  polcmd::text AS cmd,
  pg_get_expr(polqual, p.polrelid) AS using_expr
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname = 'inventory_items'
ORDER BY polname;

SELECT 'inventory_items_rows' AS check, count(*) AS count FROM inventory_items;
