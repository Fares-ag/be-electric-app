# L. PPM / Preventive Maintenance (PM Tasks)

> **Superseded in part (July 2026):** The “no PM in navigation” summary below describes the **pre–Option A** state.  
> **Current:** When `ENABLE_PM_OCCURRENCES=true`, requestors reach **Preventive Maintenance** from the overflow menu (read-only lists, detail, and **Confirm**). See `docs/PM_MIGRATION_GUIDE.md`.  
> Remaining sections document legacy `pm_tasks` context and historical RLS notes.

## User-facing purpose

**Today (Option A, flag ON):** Read-only preventive maintenance for company-scoped charger assets, plus **Confirm** on open occurrences.  
**Legacy:** `RequestorDashboardScreen` PM code is orphaned and not linked from the requestor shell.

## Screens & entry points (current)

| Screen | Reachable from requestor app? | PM behavior |
|--------|------------------------------|-------------|
| `RequestorMainScreen` | Yes (post-login home) | No PM UI |
| `RequestorStatusScreen` | Yes (My Requests) | Work orders only |
| `RequestorAnalyticsScreen` | Yes (overflow menu) | Work orders only; PM cache loaded but unused |
| `RequestorDashboardScreen` | **No** (orphaned) | Computes `myPMTasks` with wrong filter; UI ignores PM |
| `PMTaskListScreen` | **No** | Requestor branch exists (`unassigned` only) — unreachable |
| `PMTaskDetailScreen` | Only via orphaned dashboard notification handler | Shows **Start/Complete** with no requestor role gate |

Source: `role_based_navigation.dart` → `RequestorMainScreen`; `docs/requestor-db/11-overflow-menu.md`.

## Client stack (when PM data is loaded)

Requestor login still initializes full domain cache:

```
CmmsDataCoordinator.initialize()
  → UnifiedDataService.loadPMTasks()
    → SupabaseDatabaseService.getAllPMTasks()
      → from('pm_tasks').select().order('createdAt')
```

| Layer | File |
|-------|------|
| Coordinator | `lib/providers/cmms_data_coordinator.dart` |
| Service | `lib/services/unified_data_service.dart` (`loadPMTasks`, `listenToPMTasks`) |
| Repository | `lib/repositories/supabase/supabase_work_order_repository.dart` |
| DB | `lib/services/supabase_database_service.dart` (`getAllPMTasks`, `listenToPMTasks`) |

**Legacy dashboard (unreachable):**

```
RequestorDashboardScreen
  → unifiedProvider.pmTasks.where(pt => pt.hasTechnician(currentUser.id))  // wrong for requestor role
  → _buildQuickStats / _buildRecentActivity  // pmTasks parameter unused in UI
  → notification tap → PMTaskDetailScreen
```

## Database operations

| Operation | Target | Requestor today | Notes |
|-----------|--------|-----------------|-------|
| READ all PM | `pm_tasks` SELECT | **Blocked by RLS** → `[]` | No requestor policy |
| READ via realtime | `pm_tasks` stream | **Blocked** | Same RLS |
| INSERT/UPDATE/DELETE | `pm_tasks` | **Blocked** | Correct — PM execution is technician/admin |
| READ assets (link) | `assets` | Allowed | Used for maintenance requests, not PM UI |

## Table schema (live)

Key columns for requestor read-only PPM:

| Column | Use for requestor view |
|--------|------------------------|
| `taskName`, `description` | Display |
| `assetId` | Join to charger; scope by `assets.companyId` |
| `status`, `nextDueDate`, `lastCompletedDate` | Schedule / overdue |
| `assignedTechnicianIds` | Who is scheduled (names via users — requestor cannot list all users) |
| `frequency`, `metadata` | Optional detail |
| `completionPhotoPath`, signatures | Technician completion — read-only if exposed |

**No `companyId` on `pm_tasks`** — company scope must join through `assets`.

## RLS / permissions (live, June 2026)

| Policy | Command | Who |
|--------|---------|-----|
| `Admins can manage pm_tasks` | ALL | admin, manager |
| `Technicians can read assigned pm_tasks` | SELECT | assigned uid in array |
| `Technicians can update assigned pm_tasks` | UPDATE | assigned uid (T-001 fixed) |
| **Requestor read** | — | **MISSING** |

Verify: `./scripts/db.sh run scripts/sql/verify_requestor_ppm_backend.sql`

### Proposed Option B policy (not deployed)

```sql
CREATE POLICY "Requestors can read company pm_tasks"
ON public.pm_tasks FOR SELECT TO authenticated
USING (
  get_my_role() = 'requestor'
  AND "assetId" IS NOT NULL
  AND "assetId" <> ''
  AND EXISTS (
    SELECT 1
    FROM public.assets a
    JOIN public.users u ON u.id = auth.uid()::text
    WHERE a.id = pm_tasks."assetId"
      AND a."companyId" = u."companyId"
  )
);
```

## Storage

Technician completion photos: `files` bucket `pm_tasks/completion_photos/`. Requestor would need SELECT on storage if showing photos (currently authenticated read on `files` bucket).

## Gaps

| ID | Gap |
|----|-----|
| No requestor RLS | Cache always empty; any PM UI would show nothing |
| Orphan dashboard | PM logic in dead screen |
| Wrong filter | `hasTechnician(requestorId)` treats requestor as assignee |
| Unused UI params | `pmTasks` passed but not rendered |
| PMTaskDetailScreen | No read-only mode; shows technician actions to any role |
| Wasted fetch | `getAllPMTasks()` on every requestor session |
| No tests | Zero requestor PPM widget/integration tests |
| No notifications | PM due/overdue not delivered to requestor (local notifs only) |

## Failure modes

| Symptom | Cause |
|---------|-------|
| PM count always 0 | RLS + wrong filter + dead screen |
| Notification tap on `pm_task` crashes | `firstWhere` on empty `pmTasks` cache |
| Start Task visible to requestor | No role gate on `PMTaskDetailScreen` actions |

## Verification SQL

```bash
./scripts/db.sh run scripts/sql/verify_requestor_ppm_backend.sql
```

Sample live data (audit date):

- 1 `pm_tasks` row (`HVAC Inspection`, unassigned, asset `asset_170001901`, company `company-pearl-qatar`)
- 3 requestor users (companies: Doha Festival City, Doha Oasis) — **no PM rows** on their company assets today

## Related docs

- [QA_REQUESTOR_PPM_ENTERPRISE_AUDIT.md](../QA_REQUESTOR_PPM_ENTERPRISE_AUDIT.md)
- [FOR_REACT_PM_TASK_CREATION.md](../FOR_REACT_PM_TASK_CREATION.md)
- [technician-db/TECHNICIAN_DATABASE.md](../technician-db/TECHNICIAN_DATABASE.md) — PM execution RLS
