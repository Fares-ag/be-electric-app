# Technician create-WO QA run — 2026-10-04

Execution of the beginning-to-end QA plan (listed charger, field-add charger, requestor parity, lifecycle, admin/SQL).

## Phase 0 — Preconditions

| Check | Result |
|-------|--------|
| RLS `Technicians add field chargers` on `assets` (INSERT) | **Pass** — applied via `./scripts/db.sh migrate-technician-insert-field-chargers` |
| Verify script | **Pass** |
| Admin account | `beelectric@q-auto.com` (`64903eb0-…`) |
| Technician (QA) | `jeffiongg@q-auto.com` (`d171de84-166a-453e-9a44-e1dbf08ed805`) |
| Requestor (QA, DFC) | `fares@q-auto.com` (`578356fe-…`, `company-doha-festival-city`) |
| Seed Siemens charger | `asset_kos009220943qa` — 60kW.DC Charger 01 |
| Seed Kostad chargers | Multiple (e.g. `KOS009231650QA`) |
| Non-charger negative asset | `asset_jaal2cg022` — 22kW AC (EV pattern; use pump name in unit tests) |

## Automated gate

**Pass** — 48 tests (40 plan gate + 8 integration):

```bash
cd packages/cmms_core && flutter test \
  test/integration/technician_create_wo_qa_test.dart \
  test/utils/charger_asset_filter_test.dart \
  test/utils/requestor_category_mapper_test.dart \
  test/widgets/technician_create_work_order_fields_test.dart \
  test/utils/technician_work_order_filter_test.dart \
  test/widgets/technician_quick_create_test.dart
```

## Live DB seed (Phases 1–5 data contract)

**Pass** — seeded and verified via:

```bash
./scripts/db.sh run scripts/sql/qa_technician_create_wo_run.sql
./scripts/db.sh run scripts/sql/qa_technician_create_wo_verify.sql
```

| Ticket | ID | Status | Notes |
|--------|-----|--------|-------|
| WO-QA-TECH-LISTED | `qa-wo-tech-listed-20261004` | **completed** (lifecycle simulated) | Siemens listed, Electrical, assigned to tech |
| WO-QA-TECH-FIELD | `qa-wo-tech-field-20261004` | **assigned** | Field asset `qa-field-kostad-20261004`, Hardware |
| WO-QA-REQ | `qa-wo-req-20261004` | **open**, unassigned | Requestor parity, Electrical |

Field asset: `QA Field Kostad 20261004`, `assetType=charger`, Kostad, `Bay 4 QA`.

T-006 checks: 2 work orders assigned to technician; requestor row open with empty `assignedTechnicianIds`.

## Device UI (Phases 1, 2, 3, 6 snackbars/QR)

**Not run in this session** — requires technician and requestor apps on a device/simulator. Payload, list filter, Quick Create (T-005), and DB shapes above match the implemented contract in [`create_work_request_screen.dart`](../packages/cmms_core/lib/screens/work_orders/create_work_request_screen.dart).

Recommended manual pass before release:

1. Technician listed create → snackbar + list row.
2. Technician “Charger not in the system” → asset + WO online (RLS now applied).
3. Requestor create → review → success; confirm tech list excludes until assigned.
4. Phase 6 snackbar/QR negatives on device.

## Pass / fail summary

| Area | Result |
|------|--------|
| Preconditions + RLS | **Pass** |
| Automated contract tests | **Pass** |
| DB seed + lifecycle + T-006 SQL | **Pass** |
| On-device UI walkthrough | **Pending manual** |

Overall: **Pass with manual UI follow-up** for form layout, QR camera, and offline sync.
