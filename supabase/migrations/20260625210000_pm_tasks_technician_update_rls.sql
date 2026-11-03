-- PM tasks: technician UPDATE RLS (T-001)
-- Canonical copy: scripts/sql/migrate_pm_tasks_technician_update_rls.sql

BEGIN;

DROP POLICY IF EXISTS "Technicians can update assigned pm_tasks" ON public.pm_tasks;

CREATE POLICY "Technicians can update assigned pm_tasks"
  ON public.pm_tasks
  FOR UPDATE
  TO authenticated
  USING (
    (auth.uid())::text = ANY (COALESCE("assignedTechnicianIds", ARRAY[]::text[]))
  )
  WITH CHECK (
    (auth.uid())::text = ANY (COALESCE("assignedTechnicianIds", ARRAY[]::text[]))
  );

COMMENT ON POLICY "Technicians can update assigned pm_tasks" ON public.pm_tasks IS
  'Allows assigned field technicians to start, pause, and complete PM tasks. '
  'Admin/manager full access remains on "Admins can manage pm_tasks".';

COMMIT;
