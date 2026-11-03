-- T-003: Prevent orphan technician assignments
-- Canonical copy: scripts/sql/migrate_prevent_orphan_technician_assignments.sql
--
-- Root cause: delete_user_by_id removed public.users rows without scrubbing
-- assignedTechnicianIds on work_orders / pm_tasks. Technicians then lost RLS access.
--
-- Does NOT reassign existing orphans. Run report first:
--   ./scripts/db.sh report-orphan-assignments

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Scrub deleted user from assignment arrays (no reassignment)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.scrub_user_from_technician_assignments(p_user_id text)
RETURNS TABLE(work_orders_updated bigint, pm_tasks_updated bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $$
DECLARE
  v_wo bigint;
  v_pm bigint;
BEGIN
  IF p_user_id IS NULL OR btrim(p_user_id) = '' THEN
    RETURN QUERY SELECT 0::bigint, 0::bigint;
    RETURN;
  END IF;

  WITH updated AS (
    UPDATE public.work_orders wo
    SET
      "assignedTechnicianIds" = array_remove(
        COALESCE(wo."assignedTechnicianIds", ARRAY[]::text[]),
        p_user_id
      ),
      "primaryTechnicianId" = CASE
        WHEN wo."primaryTechnicianId" = p_user_id THEN
          (array_remove(COALESCE(wo."assignedTechnicianIds", ARRAY[]::text[]), p_user_id))[1]
        ELSE wo."primaryTechnicianId"
      END,
      "assignedTechnicianId" = CASE
        WHEN wo."assignedTechnicianId" = p_user_id THEN NULL
        ELSE wo."assignedTechnicianId"
      END,
      "technicianEffortMinutes" = CASE
        WHEN wo."technicianEffortMinutes" ? p_user_id THEN wo."technicianEffortMinutes" - p_user_id
        ELSE wo."technicianEffortMinutes"
      END,
      "updatedAt" = now()
    WHERE p_user_id = ANY (COALESCE(wo."assignedTechnicianIds", ARRAY[]::text[]))
       OR wo."primaryTechnicianId" = p_user_id
       OR wo."assignedTechnicianId" = p_user_id
    RETURNING 1
  )
  SELECT count(*) INTO v_wo FROM updated;

  WITH updated AS (
    UPDATE public.pm_tasks pt
    SET
      "assignedTechnicianIds" = array_remove(
        COALESCE(pt."assignedTechnicianIds", ARRAY[]::text[]),
        p_user_id
      ),
      "updatedAt" = now()
    WHERE p_user_id = ANY (COALESCE(pt."assignedTechnicianIds", ARRAY[]::text[]))
    RETURNING 1
  )
  SELECT count(*) INTO v_pm FROM updated;

  RETURN QUERY SELECT v_wo, v_pm;
END;
$$;

COMMENT ON FUNCTION public.scrub_user_from_technician_assignments(text) IS
  'Removes a user id from work_orders/pm_tasks assignment arrays. Does not assign replacements.';

-- ---------------------------------------------------------------------------
-- 2. User delete — scrub assignments first (prevents NEW orphans)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.delete_user_by_id(p_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $$
DECLARE
  scrubbed record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF public.get_my_role() NOT IN ('admin', 'manager') THEN
    RAISE EXCEPTION 'Forbidden: admin or manager role required';
  END IF;

  SELECT * INTO scrubbed FROM public.scrub_user_from_technician_assignments(p_id);

  RAISE NOTICE 'scrub_user_from_technician_assignments: work_orders=%, pm_tasks=%',
    scrubbed.work_orders_updated, scrubbed.pm_tasks_updated;

  DELETE FROM public.users WHERE id = p_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Validate assignment arrays on write (prevents invalid IDs)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.validate_assigned_technician_ids()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  missing text[];
BEGIN
  IF NEW."assignedTechnicianIds" IS NULL
     OR array_length(NEW."assignedTechnicianIds", 1) IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(array_agg(DISTINCT x), ARRAY[]::text[])
  INTO missing
  FROM unnest(NEW."assignedTechnicianIds") AS x
  WHERE x IS NOT NULL
    AND btrim(x) <> ''
    AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = x);

  IF array_length(missing, 1) IS NOT NULL THEN
    RAISE EXCEPTION
      'assignedTechnicianIds references missing users: %',
      array_to_string(missing, ', ');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_work_orders_assigned_technicians
  ON public.work_orders;

CREATE TRIGGER trg_validate_work_orders_assigned_technicians
  BEFORE INSERT OR UPDATE OF "assignedTechnicianIds"
  ON public.work_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_assigned_technician_ids();

DROP TRIGGER IF EXISTS trg_validate_pm_tasks_assigned_technicians
  ON public.pm_tasks;

CREATE TRIGGER trg_validate_pm_tasks_assigned_technicians
  BEFORE INSERT OR UPDATE OF "assignedTechnicianIds"
  ON public.pm_tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_assigned_technician_ids();

COMMIT;
