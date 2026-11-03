-- Requestor App Store QA: PM confirm columns/policy + backfill work order FKs.

BEGIN;

-- ---------------------------------------------------------------------------
-- PM confirm (from 20260630130000_requestor_pm_confirm.sql)
-- ---------------------------------------------------------------------------

ALTER TABLE public.pm_task_occurrences
  ADD COLUMN IF NOT EXISTS "requestorConfirmedAt" timestamptz,
  ADD COLUMN IF NOT EXISTS "requestorConfirmedById" text;

DO $$
BEGIN
  IF to_regprocedure('public.get_my_role()') IS NULL THEN
    RAISE EXCEPTION 'public.get_my_role() not found — apply core auth migrations first.';
  END IF;
END $$;

DROP POLICY IF EXISTS "Requestors confirm company pm_task_occurrences" ON public.pm_task_occurrences;
CREATE POLICY "Requestors confirm company pm_task_occurrences"
  ON public.pm_task_occurrences
  FOR UPDATE
  TO authenticated
  USING (
    public.get_my_role() = 'requestor'::text
    AND "completedAt" IS NULL
    AND status <> 'cancelled'
    AND "requestorConfirmedAt" IS NULL
    AND EXISTS (
      SELECT 1
      FROM public.assets a
      INNER JOIN public.users u ON u.id = (auth.uid())::text
      WHERE a.id = pm_task_occurrences."assetId"
        AND u."companyId" IS NOT NULL
        AND btrim(u."companyId") <> ''
        AND a."companyId" = u."companyId"
    )
  )
  WITH CHECK (
    public.get_my_role() = 'requestor'::text
    AND "completedAt" IS NULL
    AND status <> 'cancelled'
    AND "requestorConfirmedAt" IS NOT NULL
    AND "requestorConfirmedById" = (auth.uid())::text
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

-- ---------------------------------------------------------------------------
-- Backfill work_orders.companyId / assetId from metadata (legacy client bug)
-- ---------------------------------------------------------------------------

UPDATE public.work_orders
SET "companyId" = metadata->>'appCompanyId'
WHERE ("companyId" IS NULL OR btrim("companyId") = '')
  AND metadata->>'appCompanyId' IS NOT NULL
  AND btrim(metadata->>'appCompanyId') <> '';

UPDATE public.work_orders
SET "assetId" = metadata->>'appAssetId'
WHERE ("assetId" IS NULL OR btrim("assetId") = '')
  AND metadata->>'appAssetId' IS NOT NULL
  AND btrim(metadata->>'appAssetId') <> '';

COMMIT;
