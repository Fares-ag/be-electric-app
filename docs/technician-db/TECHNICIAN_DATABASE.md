# Technician App — Database Documentation

Maps **technician-facing** features in `apps/technician_cmms` to Supabase tables, RPCs, storage, and RLS.

| Item | Value |
|------|--------|
| App | `apps/technician_cmms` |
| Bundle ID | `com.beelectric.cmms.technicianCmms` |
| Shared package | `packages/cmms_core` |
| App mode | `CmmsAppMode.technician` |
| Supabase project | `sdhqjyjeczrbnvukrmny` |
| ID convention | `public.users.id` must equal `auth.uid()::text` |
| Storage bucket | `files` (completion photos, signatures as text/base64 in rows) |
| Last verified | Live schema via `./scripts/db.sh` (June 2026) |

## Architecture pattern

```
Screen → Provider → Service → Repository → SupabaseDatabaseService / SupabaseStorageService / SupabaseAuthService
```

Auth: `AuthProvider` → `CmmsRepositories.users` (RPC `get_user_by_email`).

Domain data: `UnifiedDataProvider` → `WorkOrderProvider` / `InventoryProvider` → `UnifiedDataService` → repositories.

## Role routing (technician build)

| `users.role` | Screen after login |
|--------------|-------------------|
| `technician` | `TechnicianMainScreen` |
| `manager`, `admin` | `AdminMainScreen` |
| `requestor` | `WrongAppRoleScreen` |

Source: `packages/cmms_core/lib/widgets/role_based_navigation.dart`.

## Feature index

| Section | Feature | Primary tables / storage |
|---------|---------|--------------------------|
| A | Bootstrap & auth | `auth.users`, `public.users`, RPCs |
| B | Technician shell | Navigation only |
| C | Dashboard stats | `work_orders`, `pm_tasks` (in-memory filter) |
| D | Work orders | `work_orders` SELECT/UPDATE |
| E | WO completion | `work_orders` UPDATE, Storage `files/work_orders/...` |
| F | PM tasks | `pm_tasks` SELECT/UPDATE (assigned) |
| G | Parts requests | `parts_requests` INSERT/SELECT, `inventory_items` SELECT (read-only) |
| H | QR / assets | `assets` SELECT |
| I | Analytics | Cached `work_orders`, `pm_tasks`, `assets` |
| J | Notifications | `notifications` + local SharedPreferences fallback |
| K | Profile / legal | `companies` SELECT, mailto deletion |
| L | Manager/admin in tech build | Same Supabase; admin UI in `AdminMainScreen` |

## Live tables used by technician

| Table | Technician READ (live RLS) | Technician WRITE (live RLS) |
|-------|------------------------------|-----------------------------|
| `users` | Own profile (`id = auth.uid()::text`) | — |
| `companies` | Authenticated read | — |
| `assets` | Authenticated read (`true`) | — |
| `work_orders` | Assigned (`assignedTechnicianIds` contains uid) **or** own as requestor | UPDATE assigned only; INSERT if `requestorId = uid` |
| `pm_tasks` | Assigned only | UPDATE assigned only (`Technicians can update assigned pm_tasks`) |
| `parts_requests` | Own (`requestedBy = uid`) | INSERT own |
| `inventory_items` | SELECT (`Technicians can read inventory`) | — (no technician write) |
| `notifications` | Own (`userId = uid`) | UPDATE own |

Verify: `./scripts/db.sh run scripts/sql/verify_technician_backend.sql`

## RPCs used at login

| RPC | Purpose |
|-----|---------|
| `get_user_by_email(p_email)` | Resolve profile after Supabase Auth sign-in |
| `insert_user(p_row)` | Auto-create row (debug / requestor path; technicians normally provisioned by admin) |

## Storage paths (bucket `files`)

| Path pattern | Feature |
|--------------|---------|
| `work_orders/completion_photos/...` | WO completion photos |
| `pm_tasks/completion_photos/...` | PM completion photos |
| `work_orders/{id}/...` | Request / WO photos |

Policies: `files_authenticated_select`, `files_authenticated_insert`, `files_authenticated_update` on bucket `files`.

## Work order list filtering (T-006 — fixed)

Technician dashboard and Work Orders tab must use the same scope: **assigned work orders only**.

| Screen / helper | Query (before) | Query (after) |
|-----------------|----------------|---------------|
| `TechnicianMainScreen` dashboard stats | `getWorkOrdersByTechnician(uid)` | unchanged |
| `WorkOrderListScreen` (`isTechnicianView` or `role == technician`) | `hasTechnician(uid) \|\| requestorId == uid` | `workOrdersForRoleListView(...)` → assigned only |
| `WorkOrderProvider.getWorkOrdersByTechnician` | `hasTechnician(uid)` | delegates to `workOrdersAssignedToTechnician` |
| `UnifiedDataService.getWorkOrdersByTechnician` | `assignedTechnicianIds.contains(uid)` | delegates to `workOrdersAssignedToTechnician` |
| Requestor list (`role == requestor`) | `requestorId == uid` | unchanged (`workOrdersForRoleListView`) |
| Admin / manager list | all `workOrders` | unchanged (`workOrdersForRoleListView`) |

Canonical helpers: `packages/cmms_core/lib/utils/technician_work_order_filter.dart`

Tests: `test/utils/technician_work_order_filter_test.dart`

## Work order completion signatures (T-004 — Option A)

Field technicians complete assigned work with **technician signature only**. Requestor sign-off is not required on the completion screen.

| Layer | Rule |
|-------|------|
| `WorkOrderCompletionScreen` | Technician signature required; requestor pad removed |
| `WorkOrderCompletionPolicy` | `requireRequestorSignatureOnTechnicianComplete = false` |
| Postgres / RLS | No signature constraints (unchanged) |
| PM tasks | Unchanged — technician signature only (`PMTaskCompletionScreen`) |

Tests: `test/utils/work_order_completion_policy_test.dart`

## Inventory RLS (T-002 — fixed)

| Policy | Command | Rule |
|--------|---------|------|
| `Technicians can read inventory` | SELECT | `get_my_role() = 'technician'` |
| `Admins manage inventory` | ALL | `get_my_role() IN ('admin','manager')` |

Migration: `./scripts/db.sh migrate-inventory-technician-select`  
Verify: `./scripts/db.sh verify-inventory-technician-select`

Flutter: `PartsRequestScreen` → `UnifiedDataProvider.inventoryItems` → `getAllInventoryItems()` (no code change required).

## Orphan technician assignments (T-003)

Work orders whose `assignedTechnicianIds` reference deleted users are invisible to live technicians (RLS). Prevention is deployed; **5 legacy work orders** still need manual remediation.

| Mechanism | Purpose |
|-----------|---------|
| `scrub_user_from_technician_assignments()` | Remove user id from arrays (no auto-reassign) |
| `delete_user_by_id()` | Scrubs assignments before user delete |
| Validation triggers on `work_orders` / `pm_tasks` | Block new invalid assignment ids |

Report: `./scripts/db.sh report-orphan-assignments`  
Migrate: `./scripts/db.sh migrate-prevent-orphan-assignments`  
Verify: `./scripts/db.sh verify-orphan-assignments`

Full write-up: [13-orphan-technician-assignments.md](./13-orphan-technician-assignments.md)

## Known backend gaps (June 2026)

1. **`parts_requests`**: Doc claims read for assigned-WO requests; live policy is **requestedBy only** (technician-created requests OK).
2. **Legacy orphan assignments**: 5 work orders still reference deleted technician `14a37af3-a545-4b4d-8187-0cf59d579775` — run report and remediate manually; prevention stops new orphans.
3. **PM task creation**: Only admin/manager `*` policy on `pm_tasks`; Quick Create hidden for technicians (T-005 UI fix).

## Related docs

- [REQUESTOR_DATABASE.md](../REQUESTOR_DATABASE.md) — shared tables
- [QA_TECHNICIAN_ENTERPRISE_AUDIT.md](../QA_TECHNICIAN_ENTERPRISE_AUDIT.md) — full QA report
- [13-orphan-technician-assignments.md](./13-orphan-technician-assignments.md) — T-003 orphan assignments
- [TECHNICIAN_APP_FUNCTIONAL_REVIEW.md](../TECHNICIAN_APP_FUNCTIONAL_REVIEW.md) — prior functional review
