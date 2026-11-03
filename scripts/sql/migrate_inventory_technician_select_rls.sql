-- Inventory: technician SELECT RLS (T-002)
--
-- Problem: inventory_items had only "Admins manage inventory" (*).
--          Technicians opening PartsRequestScreen read UnifiedDataProvider.inventoryItems
--          via getAllInventoryItems() and received [] (RLS denied).
--
-- Fix: Add read-only SELECT for role technician. No INSERT/UPDATE/DELETE for technicians.
--      Admins/managers keep full access via existing "Admins manage inventory" (*).
--
-- Apply:
--   ./scripts/db.sh migrate-inventory-technician-select
--
-- Verify:
--   ./scripts/db.sh verify-inventory-technician-select
--   ./scripts/db.sh run scripts/sql/verify_technician_backend.sql

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
