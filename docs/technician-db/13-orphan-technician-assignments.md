# T-003 — Orphan Technician Assignments

Production fix for work orders assigned to deleted users. Technicians cannot see those work orders because RLS requires `auth.uid()::text = ANY(assignedTechnicianIds)` and the stored IDs no longer exist in `public.users`.

| Item | Value |
|------|--------|
| QA finding | T-003 (P0) in [QA_TECHNICIAN_ENTERPRISE_AUDIT.md](../QA_TECHNICIAN_ENTERPRISE_AUDIT.md) |
| Live orphan count (June 2026) | 5 work orders, 1 orphan user id, 0 PM tasks |
| Orphan user id | `14a37af3-a545-4b4d-8187-0cf59d579775` |
| Prevention status | Deployed (scrub on delete + validation triggers) |
| Legacy data | **Not auto-fixed** — admin report + manual remediation only |

## Root cause

1. **`assignedTechnicianIds` is `text[]` with no foreign key** to `public.users`. Deleting a user row does not cascade to assignment arrays.

2. **Legacy `delete_user_by_id`** removed `public.users` without scrubbing `work_orders.assignedTechnicianIds` or `pm_tasks.assignedTechnicianIds`.

3. **Direct SQL or dashboard deletes** on `users` bypass application logic and leave stale IDs.

4. **RLS hides affected work orders** from all live technicians because no authenticated user matches the stored IDs.

`pm_tasks` only stores `assignedTechnicianIds` (no `primaryTechnicianId` column). `work_orders` also has legacy scalar columns `primaryTechnicianId` and `assignedTechnicianId`; scrub handles both.

## Prevention (deployed)

| Object | Purpose |
|--------|---------|
| `scrub_user_from_technician_assignments(text)` | Removes a user id from assignment arrays. **Does not assign replacements.** |
| `delete_user_by_id(text)` | Calls scrub **before** `DELETE FROM users`. |
| `validate_assigned_technician_ids()` | Trigger function; rejects INSERT/UPDATE when any id in `assignedTechnicianIds` is missing from `users`. |
| `trg_validate_work_orders_assigned_technicians` | BEFORE INSERT/UPDATE OF `assignedTechnicianIds` on `work_orders` |
| `trg_validate_pm_tasks_assigned_technicians` | BEFORE INSERT/UPDATE OF `assignedTechnicianIds` on `pm_tasks` |

Apply (idempotent):

```bash
./scripts/db.sh migrate-prevent-orphan-assignments
./scripts/db.sh verify-orphan-assignments
```

## Admin report (read-only)

Lists affected work orders / PM tasks with **recommended reassignment** (top 5 active technicians by company and recent login). Recommendations are **not applied automatically**.

```bash
./scripts/db.sh report-orphan-assignments
```

Report columns (work orders):

| Column | Description |
|--------|-------------|
| `work_order_id` | UUID |
| `ticketNumber` | Human-readable ticket |
| `status` | Work order status |
| `company_name` / `effective_company_id` | Company context for candidate ranking |
| `orphan_technician_id` | Deleted or missing user id |
| `recommended_reassignment` | Up to 5 lines: `id \| email \| name` |

### Live snapshot (June 2026)

| Ticket | Status | Orphan id | Top recommended technicians |
|--------|--------|-----------|----------------------------|
| WO-1773280496462 | open | `14a37af3-…` | `fares@gmail.com`, `faroos4848@gmail.com` |
| WO-1773280744046 | open | `14a37af3-…` | `faroos4848@gmail.com`, `fares@gmail.com` |
| WO-1773280931291 | open | `14a37af3-…` | `faroos4848@gmail.com`, `fares@gmail.com` |
| WO-1773526588905 | completed | `14a37af3-…` | `fares@gmail.com`, `faroos4848@gmail.com` |
| WO-2026-58740 | reopened | `14a37af3-…` | `faroos4848@gmail.com`, `fares@gmail.com` |

## Manual remediation (requires explicit approval)

**Do not run without reviewing the report.** No migration or script in this repo auto-reassigns or auto-scrubs legacy orphans.

Templates (commented only):

```bash
./scripts/db.sh run scripts/sql/remediate_orphan_technician_ids_manual.sql
```

**Option A — Unassign (remove dead id, no replacement):**

```sql
SELECT * FROM scrub_user_from_technician_assignments('14a37af3-a545-4b4d-8187-0cf59d579775');
```

**Option B — Reassign** to a specific live technician from the report (per work order):

```sql
UPDATE work_orders
SET "assignedTechnicianIds" = array_replace(...), "updatedAt" = now()
WHERE id = '<work_order_id>';
```

After any manual change:

```bash
./scripts/db.sh verify-orphan-assignments
```

## Verification queries

Dedicated check:

```bash
./scripts/db.sh verify-orphan-assignments
```

Also included in the technician backend suite:

```bash
./scripts/db.sh run scripts/sql/verify_technician_backend.sql
```

Expected prevention checks: all `OK`. Legacy orphan rows may still show `wo_orphan_technician_ids` = `DATA_ISSUE` until manually remediated.

## Client-side diagnostics (unchanged)

| File | Role |
|------|------|
| `packages/cmms_core/lib/utils/assignment_diagnostic.dart` | Detect orphan ids in loaded data |
| `packages/cmms_core/lib/screens/admin/assignment_diagnostic_screen.dart` | Admin UI |
| `packages/cmms_core/lib/services/orphan_cleanup_service.dart` | Removes work orders with missing **requestors** (different concern) |

User delete from the app calls `delete_user_by_id` via `SupabaseDatabaseService.deleteUser` — safe after prevention migration.

## Related files

| Path | Purpose |
|------|---------|
| `scripts/sql/report_orphan_technician_assignments.sql` | Admin report |
| `scripts/sql/migrate_prevent_orphan_technician_assignments.sql` | Prevention migration |
| `scripts/sql/verify_orphan_technician_assignments.sql` | Verification |
| `scripts/sql/remediate_orphan_technician_ids_manual.sql` | Commented manual fix templates |
| `supabase/migrations/20260629130000_prevent_orphan_technician_assignments.sql` | Supabase migration mirror |
