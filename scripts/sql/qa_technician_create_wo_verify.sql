-- Assertions for technician create-WO QA run.

SELECT 'work_orders' AS section, id, "ticketNumber", status, priority, category,
       "assetId", "requestorId", "assignedTechnicianIds",
       "customerName", "customerPhone", "customerEmail",
       LEFT(notes, 80) AS notes_preview,
       "problemDescription"
FROM work_orders
WHERE "problemDescription" LIKE 'QA-%'
ORDER BY "createdAt" DESC;

SELECT 'field_asset' AS section, id, name, location, manufacturer, "assetType",
       "serialNumber", "qrCode", "companyId"
FROM assets
WHERE name LIKE 'QA Field Kostad%'
ORDER BY "createdAt" DESC;

-- T-006: technician assigned scope (should be 2 assigned tech WOs, not requestor open)
SELECT 'tech_assigned_count' AS check_name,
       COUNT(*) AS cnt
FROM work_orders
WHERE "problemDescription" LIKE 'QA-%'
  AND 'd171de84-166a-453e-9a44-e1dbf08ed805' = ANY("assignedTechnicianIds");

SELECT 'req_unassigned' AS check_name,
       COUNT(*) AS cnt
FROM work_orders
WHERE id = 'qa-wo-req-20261004'
  AND status = 'open'
  AND COALESCE(array_length("assignedTechnicianIds", 1), 0) = 0;

SELECT 'listed_completed' AS check_name,
       status,
       "completedAt" IS NOT NULL AS has_completed_at,
       "technicianSignature" IS NOT NULL AS has_tech_signature
FROM work_orders
WHERE id = 'qa-wo-tech-listed-20261004';
