-- Fix requestor submit: work_orders.id is text, but upsert_work_order used uuid
-- for v_work_order_id, causing "operator does not exist: text = uuid" (42883).

BEGIN;

CREATE OR REPLACE FUNCTION public.upsert_work_order(p_row jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid text := auth.uid()::text;
  v_role text := public.get_my_role();
  v_requestor_id text := nullif(trim(p_row->>'requestorId'), '');
  v_work_order_id text := nullif(trim(p_row->>'id'), '');
  v_existing_requestor text;
  v_photo_path text;
  v_completion_photo_path text;
  v_status text;
  v_assignees text[];
  v_primary text;
  v_completion_path text;
  v_before_path text;
  v_after_path text;
  v_row_exists boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_role NOT IN ('admin', 'manager') THEN
    IF v_requestor_id IS NULL OR v_requestor_id <> v_uid THEN
      RAISE EXCEPTION 'Forbidden: requestorId must match authenticated user';
    END IF;
    IF v_work_order_id IS NOT NULL THEN
      SELECT "requestorId" INTO v_existing_requestor
      FROM public.work_orders
      WHERE id = v_work_order_id;
      IF FOUND AND v_existing_requestor IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'Forbidden: cannot modify another user''s work order';
      END IF;
      v_row_exists := FOUND;
    END IF;
  END IF;

  v_photo_path := nullif(trim(p_row->>'photoPath'), '');
  IF v_photo_path IS NULL
    AND jsonb_typeof(p_row->'photoPaths') = 'array'
    AND jsonb_array_length(p_row->'photoPaths') > 0
  THEN
    v_photo_path := (p_row->'photoPaths')::text;
  END IF;

  IF v_role IN ('admin', 'manager') THEN
    v_status := COALESCE(p_row->>'status', 'open');
    v_assignees := CASE
      WHEN p_row ? 'assignedTechnicianIds'
        THEN ARRAY(SELECT jsonb_array_elements_text(p_row->'assignedTechnicianIds'))
      ELSE NULL
    END;
    v_primary := nullif(trim(p_row->>'primaryTechnicianId'), '');
    v_completion_photo_path := nullif(trim(p_row->>'completionPhotoPath'), '');
    IF v_completion_photo_path IS NULL
      AND jsonb_typeof(p_row->'completionPhotoPaths') = 'array'
      AND jsonb_array_length(p_row->'completionPhotoPaths') > 0
    THEN
      v_completion_photo_path := (p_row->'completionPhotoPaths')::text;
    END IF;
    v_before_path := nullif(trim(p_row->>'beforePhotoPath'), '');
    v_after_path := nullif(trim(p_row->>'afterPhotoPath'), '');
  ELSE
    IF v_work_order_id IS NOT NULL AND v_row_exists THEN
      SELECT
        status,
        "assignedTechnicianIds",
        "primaryTechnicianId",
        "completionPhotoPath",
        "beforePhotoPath",
        "afterPhotoPath"
      INTO
        v_status,
        v_assignees,
        v_primary,
        v_completion_photo_path,
        v_before_path,
        v_after_path
      FROM public.work_orders
      WHERE id = v_work_order_id;
    ELSE
      v_status := 'open';
      v_assignees := NULL;
      v_primary := NULL;
      v_completion_photo_path := NULL;
      v_before_path := NULL;
      v_after_path := NULL;
    END IF;
  END IF;

  INSERT INTO public.work_orders (
    id,
    "ticketNumber",
    "problemDescription",
    status,
    priority,
    "createdAt",
    "requestorId",
    "companyId",
    "assetId",
    "assignedTechnicianIds",
    "requestorName",
    "primaryTechnicianId",
    "updatedAt",
    "photoPath",
    "completionPhotoPath",
    "beforePhotoPath",
    "afterPhotoPath",
    "location",
    "category",
    "notes",
    "metadata"
  )
  VALUES (
    COALESCE(v_work_order_id, gen_random_uuid()::text),
    COALESCE(
      p_row->>'ticketNumber',
      'WO-' || to_char(now(), 'YYYYMMDD') || '-' || substr(md5(random()::text), 1, 4)
    ),
    p_row->>'problemDescription',
    v_status,
    COALESCE(p_row->>'priority', 'medium'),
    COALESCE((p_row->>'createdAt')::timestamptz, now()),
    v_requestor_id,
    nullif(trim(p_row->>'companyId'), ''),
    nullif(trim(p_row->>'assetId'), ''),
    v_assignees,
    p_row->>'requestorName',
    v_primary,
    now(),
    v_photo_path,
    v_completion_photo_path,
    v_before_path,
    v_after_path,
    nullif(trim(p_row->>'location'), ''),
    nullif(trim(p_row->>'category'), ''),
    nullif(trim(p_row->>'notes'), ''),
    CASE WHEN p_row ? 'metadata' THEN p_row->'metadata' ELSE NULL END
  )
  ON CONFLICT (id) DO UPDATE SET
    "problemDescription"    = COALESCE(EXCLUDED."problemDescription",    work_orders."problemDescription"),
    status                  = EXCLUDED.status,
    priority                = COALESCE(EXCLUDED.priority,                work_orders.priority),
    "requestorId"           = COALESCE(EXCLUDED."requestorId",           work_orders."requestorId"),
    "companyId"             = COALESCE(EXCLUDED."companyId",             work_orders."companyId"),
    "assetId"               = COALESCE(EXCLUDED."assetId",               work_orders."assetId"),
    "assignedTechnicianIds" = EXCLUDED."assignedTechnicianIds",
    "requestorName"         = COALESCE(EXCLUDED."requestorName",         work_orders."requestorName"),
    "primaryTechnicianId"   = EXCLUDED."primaryTechnicianId",
    "updatedAt"             = now(),
    "photoPath"             = COALESCE(EXCLUDED."photoPath",             work_orders."photoPath"),
    "completionPhotoPath"   = EXCLUDED."completionPhotoPath",
    "beforePhotoPath"       = COALESCE(EXCLUDED."beforePhotoPath",       work_orders."beforePhotoPath"),
    "afterPhotoPath"        = COALESCE(EXCLUDED."afterPhotoPath",        work_orders."afterPhotoPath"),
    "location"              = COALESCE(EXCLUDED."location",              work_orders."location"),
    "category"              = COALESCE(EXCLUDED."category",              work_orders."category"),
    "notes"                 = COALESCE(EXCLUDED."notes",                 work_orders."notes"),
    "metadata"              = CASE
      WHEN EXCLUDED."metadata" IS NOT NULL
        THEN COALESCE(work_orders."metadata", '{}'::jsonb) || EXCLUDED."metadata"
      ELSE work_orders."metadata"
    END;
END;
$function$;

COMMIT;
