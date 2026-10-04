-- Technician create-WO QA seed + verify (run via ./scripts/db.sh run ...)
-- Idempotent: deletes prior QA rows with matching problemDescription prefix.

BEGIN;

DELETE FROM work_orders
WHERE "problemDescription" LIKE 'QA-%';

DELETE FROM assets
WHERE name LIKE 'QA Field Kostad%';

-- Phase 2: field-added charger (mirrors buildFieldAddedCharger)
INSERT INTO assets (
  id, name, location, manufacturer, "assetType", "serialNumber", "qrCode",
  status, "companyId", "createdAt", "updatedAt"
) VALUES (
  'qa-field-kostad-20261004',
  'QA Field Kostad 20261004',
  'Bay 4 QA',
  'Kostad',
  'charger',
  'SN-QA-001',
  'TAG-QA-001',
  'active',
  'company-doha-festival-city',
  NOW(),
  NOW()
);

-- Phase 1: technician listed (assigned)
INSERT INTO work_orders (
  id, "ticketNumber", "assetId", "problemDescription", "requestorId",
  "requestorName", "customerName", "customerPhone", "customerEmail",
  status, priority, category, notes,
  "assignedTechnicianIds", "primaryTechnicianId", "assignedAt",
  "createdAt", "updatedAt"
) VALUES (
  'qa-wo-tech-listed-20261004',
  'WO-QA-TECH-LISTED',
  'asset_kos009220943qa',
  'QA-TECH-LISTED-20261004 Siemens electrical fault on listed charger',
  'd171de84-166a-453e-9a44-e1dbf08ed805',
  'QA Tech Contact',
  'QA Tech Contact',
  '+97450000000',
  'qa-tech@q-auto.com',
  'assigned',
  'high',
  'electrical',
  E'Department: N/A\nCharger: Siemens\nCharger ID: ASSET_KOS009220943QA\nCategory Issue: Electrical',
  ARRAY['d171de84-166a-453e-9a44-e1dbf08ed805']::text[],
  'd171de84-166a-453e-9a44-e1dbf08ed805',
  NOW(),
  NOW(),
  NOW()
);

-- Phase 2: technician field (assigned)
INSERT INTO work_orders (
  id, "ticketNumber", "assetId", location, "problemDescription", "requestorId",
  "requestorName", "customerName", "customerPhone", "customerEmail",
  status, priority, category, notes,
  "assignedTechnicianIds", "primaryTechnicianId", "assignedAt",
  "createdAt", "updatedAt"
) VALUES (
  'qa-wo-tech-field-20261004',
  'WO-QA-TECH-FIELD',
  'qa-field-kostad-20261004',
  'Bay 4 QA',
  'QA-TECH-FIELD-20261004 hardware issue on field-added Kostad charger',
  'd171de84-166a-453e-9a44-e1dbf08ed805',
  'QA Tech Contact',
  'QA Tech Contact',
  '+97450000000',
  'qa-tech@q-auto.com',
  'assigned',
  'medium',
  'specializedEquipment',
  E'Department: N/A\nCharger: Kostad\nCharger ID: TAG-QA-001\nCategory Issue: Hardware',
  ARRAY['d171de84-166a-453e-9a44-e1dbf08ed805']::text[],
  'd171de84-166a-453e-9a44-e1dbf08ed805',
  NOW(),
  NOW(),
  NOW()
);

-- Phase 3: requestor (open, unassigned)
INSERT INTO work_orders (
  id, "ticketNumber", "assetId", "problemDescription", "requestorId",
  "customerName", "customerPhone", "customerEmail",
  status, priority, category, notes,
  "assignedTechnicianIds",
  "createdAt", "updatedAt"
) VALUES (
  'qa-wo-req-20261004',
  'WO-QA-REQ',
  'asset_kos009220943qa',
  'QA-REQ-20261004 electrical parity with technician listed create',
  '578356fe-598b-458a-bbb4-57eb804a9fda',
  'QA Requestor',
  '+97451111111',
  'qa-req@q-auto.com',
  'open',
  'high',
  'electrical',
  E'Department: Engineering\nCharger: Siemens\nCharger ID: ASSET_KOS009220943QA\nCategory Issue: Electrical',
  ARRAY[]::text[],
  NOW(),
  NOW()
);

COMMIT;

-- Phase 4: lifecycle on listed tech WO (start + complete)
UPDATE work_orders
SET status = 'inProgress',
    "startedAt" = NOW(),
    "updatedAt" = NOW()
WHERE id = 'qa-wo-tech-listed-20261004';

UPDATE work_orders
SET status = 'completed',
    "completedAt" = NOW(),
    "technicianSignature" = 'data:image/png;base64,QA_SIGNATURE_PLACEHOLDER',
    "updatedAt" = NOW()
WHERE id = 'qa-wo-tech-listed-20261004';
