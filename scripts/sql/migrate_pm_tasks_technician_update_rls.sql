-- PM tasks: technician UPDATE RLS (T-001)
--
-- Problem: Technicians could SELECT assigned pm_tasks but had no UPDATE policy.
--          Start / pause / complete flows call SupabaseDatabaseService.updatePMTask
--          and fail with Postgres RLS "permission denied".
--
-- Fix: Add a least-privilege UPDATE policy mirroring work_orders assignment rules.
--      Admins/managers keep full access via existing "Admins can manage pm_tasks" (*).
--
-- Apply:
--   ./scripts/db.sh migrate-pm-tasks-technician-update
--
-- Verify:
--   ./scripts/db.sh verify-pm-tasks-technician-update
--   ./scripts/db.sh run scripts/sql/verify_technician_backend.sql

BEGIN;

-- Idempotent: safe to re-run
DROP POLICY IF EXISTS "Technicians can update assigned pm_tasks" ON public.pm_tasks;

-- Match work_orders technician update semantics:
--   auth.uid()::text must appear in assignedTechnicianIds (existing row for USING,
--   new row for WITH CHECK to block self-removal / assignment escape).
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
