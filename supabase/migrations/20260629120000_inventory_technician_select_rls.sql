-- Inventory: technician SELECT RLS (T-002)
-- Canonical copy: scripts/sql/migrate_inventory_technician_select_rls.sql

BEGIN;

DROP POLICY IF EXISTS "Technicians can read inventory" ON public.inventory_items;

CREATE POLICY "Technicians can read inventory"
  ON public.inventory_items
  FOR SELECT
  TO authenticated
  USING (get_my_role() = 'technician'::text);

COMMENT ON POLICY "Technicians can read inventory" ON public.inventory_items IS
  'Read-only catalog access for parts requests. Mutations remain admin/manager only.';

COMMIT;
