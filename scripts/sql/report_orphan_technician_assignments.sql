-- T-003: Orphan technician assignment — admin report (READ ONLY)
--
-- Lists work orders / PM tasks whose assignedTechnicianIds reference deleted users.
-- Includes recommended active technicians for manual reassignment (NOT applied).
--
-- Run:
--   ./scripts/db.sh report-orphan-assignments
--
-- Does NOT modify data.

-- =============================================================================
-- Summary counts
-- =============================================================================

SELECT 'orphan_work_order_rows' AS report_section,
  count(*) AS orphan_assignment_rows,
  count(DISTINCT wo.id) AS affected_work_orders
FROM work_orders wo
CROSS JOIN LATERAL unnest(COALESCE(wo."assignedTechnicianIds", ARRAY[]::text[])) tid
WHERE tid <> ''
  AND NOT EXISTS (SELECT 1 FROM users u WHERE u.id = tid);

SELECT 'orphan_pm_task_rows' AS report_section,
  count(*) AS orphan_assignment_rows,
  count(DISTINCT pt.id) AS affected_pm_tasks
FROM pm_tasks pt
CROSS JOIN LATERAL unnest(COALESCE(pt."assignedTechnicianIds", ARRAY[]::text[])) tid
WHERE tid <> ''
  AND NOT EXISTS (SELECT 1 FROM users u WHERE u.id = tid);

-- =============================================================================
-- Work orders — detail + recommended reassignment
-- =============================================================================

WITH orphan_rows AS (
  SELECT
    wo.id AS work_order_id,
    wo."ticketNumber",
    wo.status,
    wo."requestorId",
    COALESCE(wo."companyId", req."companyId") AS effective_company_id,
    comp.name AS company_name,
    tid AS orphan_technician_id
  FROM work_orders wo
  CROSS JOIN LATERAL unnest(COALESCE(wo."assignedTechnicianIds", ARRAY[]::text[])) tid
  LEFT JOIN users req ON req.id = wo."requestorId"
  LEFT JOIN companies comp ON comp.id = COALESCE(wo."companyId", req."companyId")
  WHERE tid <> ''
    AND NOT EXISTS (SELECT 1 FROM users u WHERE u.id = tid)
),
candidates AS (
  SELECT
    o.work_order_id,
    o.orphan_technician_id,
    u.id AS candidate_id,
    u.email AS candidate_email,
    u.name AS candidate_name,
    u."companyId" AS candidate_company_id,
    row_number() OVER (
      PARTITION BY o.work_order_id, o.orphan_technician_id
      ORDER BY
        CASE WHEN o.effective_company_id IS NOT NULL AND u."companyId" = o.effective_company_id THEN 0 ELSE 1 END,
        u."lastLoginAt" DESC NULLS LAST,
        u.email
    ) AS rn
  FROM orphan_rows o
  CROSS JOIN users u
  WHERE u.role = 'technician'
    AND COALESCE(u."isActive", true) = true
    AND u.id <> o.orphan_technician_id
    AND (
      o.effective_company_id IS NULL
      OR u."companyId" = o.effective_company_id
      OR u."companyId" IS NULL
    )
)
SELECT
  'work_order_detail' AS report_section,
  o.work_order_id,
  o."ticketNumber",
  o.status,
  o.company_name,
  o.effective_company_id,
  o.orphan_technician_id,
  (
    SELECT string_agg(
      c.candidate_id || ' | ' || c.candidate_email || ' | ' || c.candidate_name,
      E'\n' ORDER BY c.rn
    )
    FROM candidates c
    WHERE c.work_order_id = o.work_order_id
      AND c.orphan_technician_id = o.orphan_technician_id
      AND c.rn <= 5
  ) AS recommended_reassignment
FROM orphan_rows o
ORDER BY o."ticketNumber", o.orphan_technician_id;

-- =============================================================================
-- PM tasks — detail + recommended reassignment
-- =============================================================================

WITH orphan_pm AS (
  SELECT
    pt.id AS pm_task_id,
    pt."taskName",
    pt.status,
    pt."assetId",
    a."companyId" AS effective_company_id,
    comp.name AS company_name,
    tid AS orphan_technician_id
  FROM pm_tasks pt
  CROSS JOIN LATERAL unnest(COALESCE(pt."assignedTechnicianIds", ARRAY[]::text[])) tid
  LEFT JOIN assets a ON a.id = pt."assetId" AND pt."assetId" <> ''
  LEFT JOIN companies comp ON comp.id = a."companyId"
  WHERE tid <> ''
    AND NOT EXISTS (SELECT 1 FROM users u WHERE u.id = tid)
),
pm_candidates AS (
  SELECT
    o.pm_task_id,
    o.orphan_technician_id,
    u.id AS candidate_id,
    u.email AS candidate_email,
    u.name AS candidate_name,
    row_number() OVER (
      PARTITION BY o.pm_task_id, o.orphan_technician_id
      ORDER BY
        CASE WHEN o.effective_company_id IS NOT NULL AND u."companyId" = o.effective_company_id THEN 0 ELSE 1 END,
        u."lastLoginAt" DESC NULLS LAST,
        u.email
    ) AS rn
  FROM orphan_pm o
  CROSS JOIN users u
  WHERE u.role = 'technician'
    AND COALESCE(u."isActive", true) = true
    AND u.id <> o.orphan_technician_id
    AND (
      o.effective_company_id IS NULL
      OR u."companyId" = o.effective_company_id
      OR u."companyId" IS NULL
    )
)
SELECT
  'pm_task_detail' AS report_section,
  o.pm_task_id,
  o."taskName",
  o.status,
  o.company_name,
  o.orphan_technician_id,
  (
    SELECT string_agg(
      c.candidate_id || ' | ' || c.candidate_email || ' | ' || c.candidate_name,
      E'\n' ORDER BY c.rn
    )
    FROM pm_candidates c
    WHERE c.pm_task_id = o.pm_task_id
      AND c.orphan_technician_id = o.orphan_technician_id
      AND c.rn <= 5
  ) AS recommended_reassignment
FROM orphan_pm o
ORDER BY o."taskName", o.orphan_technician_id;

-- =============================================================================
-- Manual remediation templates (DO NOT RUN without approval)
-- =============================================================================

SELECT 'manual_fix_template' AS report_section,
  '-- Replace OLD_TECH_ID and NEW_TECH_ID, then run as admin after approval' AS note,
  'UPDATE work_orders SET "assignedTechnicianIds" = array_replace("assignedTechnicianIds", ''OLD_TECH_ID'', ''NEW_TECH_ID''), "updatedAt" = now() WHERE id = ''WORK_ORDER_ID'';' AS example_sql;
