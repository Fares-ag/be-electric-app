-- Requestor read-only RLS for Option A PM (mobile requestor PM module).
-- See docs/PM_MIGRATION_GUIDE.md

DO $$
BEGIN
  IF to_regprocedure('public.get_my_role()') IS NULL THEN
    RAISE EXCEPTION 'public.get_my_role() not found — apply core auth migrations first.';
  END IF;
END $$;

DROP POLICY IF EXISTS "Requestors read company pm_task_occurrences" ON public.pm_task_occurrences;
CREATE POLICY "Requestors read company pm_task_occurrences"
  ON public.pm_task_occurrences
  FOR SELECT
  TO authenticated
  USING (
    public.get_my_role() = 'requestor'::text
    AND EXISTS (
      SELECT 1
      FROM public.assets a
      INNER JOIN public.users u ON u.id = (auth.uid())::text
      WHERE a.id = pm_task_occurrences."assetId"
        AND u."companyId" IS NOT NULL
        AND btrim(u."companyId") <> ''
        AND a."companyId" = u."companyId"
    )
  );

DROP POLICY IF EXISTS "Requestors read company pm_schedules" ON public.pm_schedules;
CREATE POLICY "Requestors read company pm_schedules"
  ON public.pm_schedules
  FOR SELECT
  TO authenticated
  USING (
    public.get_my_role() = 'requestor'::text
    AND "companyId" IS NOT NULL
    AND btrim("companyId") <> ''
    AND "companyId" = (
      SELECT u."companyId"
      FROM public.users u
      WHERE u.id = (auth.uid())::text
    )
  );
