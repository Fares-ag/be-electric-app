# Technician company→charger create QA — 2026-10-05

## Automated gate

**57/57 pass** (`charger_asset_filter`, category mapper, list filter T-006, completion T-004, create payload, Quick Create T-005, company-first integration).

## Live backend

| Check | Result |
|-------|--------|
| Technicians SELECT all `companies` (`Staff read all companies`) | Pass |
| Technicians SELECT all `assets` (`Staff read all assets`) | Pass |
| Technicians INSERT field chargers | Pass |
| Chargers with `companyId` | 54 / 54 |
| Sample: `asset_kos009220943qa` → Military Medical City Hospital | Pass |

## Contract (create → list → complete)

| Step | Result |
|------|--------|
| Company picker lists companies; charger list is that company only | Pass (unit + live linkage) |
| Non-chargers excluded | Pass |
| Field-add stores selected `companyId` | Pass (code + test) |
| WO auto-assigned, appears on technician list | Pass (T-006 tests) |
| Complete with technician signature only | Pass (T-004 tests) |

## Not run on device

Form layout, QR bind, snackbars, and a live Start → Complete on a new ticket.

## Residual risk

`Asset.copyWith` has no `companyId` argument (existing). Field-add uses the constructor, so create is unaffected.
