# T-003 — Orphan technician assignments

Work orders and PM tasks store technician user IDs in `assignedTechnicianIds` (`text[]`). RLS grants technicians access only when `auth.uid()::text = ANY(assignedTechnicianIds)`. If an ID references a deleted user, **no live technician can see or update that row**.

## Root cause

| Step | What happened |
|------|----------------|
| 1 | Admin deletes a user via `delete_user_by_id(p_id)` (Flutter: `UserManagementScreen` → `SupabaseDatabaseService.deleteUser`). |
| 2 | **Before T-003:** RPC only ran `DELETE FROM public.users WHERE id = p_id`. |
| 3 | Existing `work_orders` / `pm_tasks` rows kept the deleted ID in `assignedTechnicianIds`. |
| 4 | Technician SELECT/UPDATE policies fail the array check → assigned work becomes invisible. |

Client-side `UnifiedDataService.validateReferences()` checks the in-memory user cache only; it does not block writes when a stale ID is already in the database or when deletion happens outside the app.

**Live impact (June 2026):** 5 work orders reference orphan technician `14a37af3-a545-4b4d-8187-0cf59d579775` (user not in `public.users`). 0 PM task orphans.

## Prevention (deployed)

Migration: `./scripts/db.sh migrate-prevent-orphan-assignments`  
Supabase: `supabase/migrations/20260629130000_prevent_orphan_technician_assignments.sql`

| Object | Purpose |
|--------|---------|
| `scrub_user_from_technician_assignments(p_user_id)` | Removes user ID from `work_orders` and `pm_tasks` assignment arrays. Clears related `primaryTechnicianId`, `assignedTechnicianId`, and `technicianEffortMinutes` keys on work orders. **Does not assign replacements.** |
| `delete_user_by_id(p_id)` | Calls scrub **before** `DELETE FROM users`. |
| `validate_assigned_technician_ids()` + triggers | `BEFORE INSERT OR UPDATE OF assignedTechnicianIds` on `work_orders` and `pm_tasks`. Rejects IDs not present in `public.users`. |

Existing orphan rows are **not** modified by the migration. Manual remediation requires explicit approval.

## Admin report (read-only)

```bash
./scripts/db.sh report-orphan-assignments
```

Script: `scripts/sql/report_orphan_technician_assignments.sql`

Output sections:

| Section | Content |
|---------|---------|
| Summary counts | Orphan assignment rows on work orders and PM tasks |
| `work_order_detail` | Ticket, status, company, orphan technician ID, up to 5 recommended active technicians (company-matched, by recent login) |
| `pm_task_detail` | Same for PM tasks |
| `manual_fix_template` | Example SQL — **do not run without approval** |

Recommended technicians are suggestions only. The report does **not** reassign work.

## Verification

```bash
./scripts/db.sh verify-orphan-assignments
./scripts/db.sh run scripts/sql/verify_technician_backend.sql
```

| Check | Expected after migration |
|-------|--------------------------|
| `fn_scrub_user_from_technician_assignments` | OK |
| `delete_user_scrubs_assignments` | OK |
| Triggers on `work_orders`, `pm_tasks` | OK |
| `wo_orphan_technician_ids` | **DATA_ISSUE** until existing 5 rows are manually fixed |

## Manual remediation (requires approval)

1. Run `./scripts/db.sh report-orphan-assignments` and save output.
2. For each row, pick a technician from `recommended_reassignment` (or another valid active technician).
3. Apply an approved UPDATE (example):

```sql
UPDATE work_orders
SET
  "assignedTechnicianIds" = array_replace("assignedTechnicianIds", 'OLD_TECH_ID', 'NEW_TECH_ID'),
  "primaryTechnicianId" = CASE WHEN "primaryTechnicianId" = 'OLD_TECH_ID' THEN 'NEW_TECH_ID' ELSE "primaryTechnicianId" END,
  "assignedTechnicianId" = CASE WHEN "assignedTechnicianId" = 'OLD_TECH_ID' THEN 'NEW_TECH_ID' ELSE "assignedTechnicianId" END,
  "updatedAt" = now()
WHERE id = 'WORK_ORDER_ID';
```

Alternatively, clear assignments (work becomes unassigned; admin must reassign in UI):

```sql
UPDATE work_orders
SET
  "assignedTechnicianIds" = array_remove("assignedTechnicianIds", 'OLD_TECH_ID'),
  "updatedAt" = now()
WHERE id = 'WORK_ORDER_ID';
```

4. Re-run `./scripts/db.sh verify-orphan-assignments` until `wo_orphan_technician_ids` is OK.

## Related

- [TECHNICIAN_DATABASE.md](./TECHNICIAN_DATABASE.md) — technician RLS overview
- [QA_TECHNICIAN_ENTERPRISE_AUDIT.md](../QA_TECHNICIAN_ENTERPRISE_AUDIT.md) — T-003 finding
- `packages/cmms_core/lib/services/orphan_cleanup_service.dart` — client-side diagnostic helper (does not fix DB)
