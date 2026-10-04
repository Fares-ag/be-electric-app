-- Technicians may INSERT charger rows so they can add a charger that is
-- not in the catalog and immediately create a work order on it.
-- Canonical copy: scripts/sql/migrate_technician_insert_field_chargers.sql

BEGIN;

DROP POLICY IF EXISTS "Technicians add field chargers" ON public.assets;

CREATE POLICY "Technicians add field chargers"
  ON public.assets
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.get_my_role() = 'technician'
    AND COALESCE("assetType", '') ILIKE '%charger%'
  );

COMMENT ON POLICY "Technicians add field chargers" ON public.assets IS
  'Field techs may add unlisted chargers, then create work orders on them. Other asset types stay admin/manager.';

COMMIT;
