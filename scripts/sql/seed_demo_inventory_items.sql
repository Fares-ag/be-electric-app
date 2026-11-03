-- Minimal demo inventory for technician Parts Request QA.
-- Idempotent by fixed ids. Safe to re-run.
--
-- Apply:
--   ./scripts/db.sh run scripts/sql/seed_demo_inventory_items.sql
--
-- Verify:
--   ./scripts/db.sh query "SELECT id, name, sku, \"currentStock\", unit FROM inventory_items ORDER BY name;"

BEGIN;

INSERT INTO public.inventory_items (
  id,
  name,
  sku,
  description,
  category,
  "currentStock",
  "minStock",
  "maxStock",
  unit,
  "unitCost",
  location,
  supplier,
  "createdAt",
  "updatedAt",
  metadata
)
VALUES
  (
    'inv-demo-cable-connector',
    'EV Cable Connector',
    'DEMO-CONN-001',
    'Demo part for technician parts-request QA',
    'Electrical',
    25,
    5,
    100,
    'pcs',
    45.00,
    'Warehouse A',
    'Be Electric Demo',
    now(),
    now(),
    '{"demo": true, "purpose": "technician_parts_qa"}'::jsonb
  ),
  (
    'inv-demo-air-filter',
    'Charger Air Filter',
    'DEMO-FILT-001',
    'Demo consumable for technician parts-request QA',
    'Consumables',
    40,
    10,
    200,
    'pcs',
    12.50,
    'Warehouse A',
    'Be Electric Demo',
    now(),
    now(),
    '{"demo": true, "purpose": "technician_parts_qa"}'::jsonb
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  sku = EXCLUDED.sku,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  "currentStock" = EXCLUDED."currentStock",
  "minStock" = EXCLUDED."minStock",
  "maxStock" = EXCLUDED."maxStock",
  unit = EXCLUDED.unit,
  "unitCost" = EXCLUDED."unitCost",
  location = EXCLUDED.location,
  supplier = EXCLUDED.supplier,
  "updatedAt" = now(),
  metadata = EXCLUDED.metadata;

COMMIT;
