# PM Migration Guide (Option A)

This document describes the preventive maintenance (PM) migration from legacy
`pm_tasks` to Option A (`pm_schedules` + `pm_task_occurrences`), how the mobile
apps merge both sources, and role-specific responsibilities.

## Feature flag

| Define | Default | Effect |
|--------|---------|--------|
| `ENABLE_PM_OCCURRENCES` | **OFF** | Legacy `pm_tasks` only; requestor PM module hidden |
| `ENABLE_PM_OCCURRENCES=true` | — | Unified inbox + requestor read-only PM + occurrence completion |

Set at build time:

```bash
flutter run --dart-define=ENABLE_PM_OCCURRENCES=true
```

Production: configure in `scripts/defines.production.json` before store release.

## Architecture split

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation layer                       │
│  PmWorkItem (UI-only merge, never persisted)                │
│  PmInboxProvider → technician inbox + requestor PM lists      │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
┌─────────────────┐               ┌──────────────────────────┐
│ Legacy pm_tasks │               │ Option A occurrences      │
│ PMTask model    │               │ PmOccurrence model        │
│ WorkOrderProvider│              │ PmOccurrenceProvider      │
│ Admin legacy UI │               │ Occurrence completion     │
└─────────────────┘               └──────────────────────────┘
```

**Rule:** Screens never call repositories directly. Flow is always:

`Screen → Provider → Service → Repository → Supabase`

## Legacy freeze policy

Legacy `PMTask` / `pm_tasks` is **maintenance-only**:

| Allowed | Not allowed |
|---------|-------------|
| Bug fixes, RLS/security patches | New fields on `PMTask` |
| Existing admin create/complete flows | New provider methods for legacy PM |
| Legacy completion for in-flight tasks | New requestor write paths |
| Unified inbox **read** of legacy rows | UI expansion on `PMTaskListScreen` |

New PM work uses `pm_schedules` + `pm_task_occurrences` when the flag is ON.

Policy markers in code: `PMTask`, `PmWorkItem`, `PmInboxProvider`,
`WorkOrderProvider.createPMTask`, `PMTaskListScreen`, `validatePMTask`.

## Unified inbox merge

`PmInboxProvider` merges:

1. **Legacy:** `WorkOrderProvider.pmTasks`
2. **Occurrences:** `PmOccurrenceProvider.occurrences` (only when flag ON)

Merge rules (`lib/utils/pm_work_item_mapper.dart`):

- No cross-source deduplication — both rows appear if IDs collide during migration
- Sort: due date ↑ → overdue first → legacy before occurrence → id

### Validation hooks (debug builds)

`lib/utils/pm_inbox_validation.dart` runs on every inbox recompute in debug:

| Check | Severity |
|-------|----------|
| Inbox matches fresh `PmWorkItem.mergeAndSort` | Error |
| Duplicate `(source, id)` in inbox | Error |
| Missing legacy/occurrence payload on item | Error |
| Same ID in legacy + occurrence tables | **Warning** (migration metric) |

Access via `PmInboxProvider.validationReport` in tests and debug builds.

## Routing

Centralized in `lib/utils/pm_work_item_navigation.dart`:

| Role | Legacy tap | Occurrence tap |
|------|------------|----------------|
| **Technician** | `PMTaskDetailScreen` (full legacy completion) | `PmOccurrenceDetailScreen` → completion |
| **Requestor** | `RequestorPmDetailScreen` (read-only summary) | `PmOccurrenceDetailScreen(readOnly: true)` |

## Technician responsibilities

When `ENABLE_PM_OCCURRENCES` is ON:

| Capability | Legacy `pm_tasks` | Occurrences |
|------------|-------------------|-------------|
| View in unified inbox | ✔ | ✔ |
| Complete | ✔ (legacy flow) | ✔ (`PmOccurrenceCompletionScreen`) |
| Upload photo / notes | ✔ (legacy) | ✔ (occurrence) |
| Create schedule | ✗ (admin/React) | ✗ (admin/React) |

**Primary UI:** PM tab → `PmTechnicianInboxScreen` → `PmInboxListBody`

Data load: `CmmsDataCoordinator` → `PmOccurrenceProvider.loadAssignedOccurrences`

## Requestor responsibilities

When `ENABLE_PM_OCCURRENCES` is ON:

### Requestors may

| Capability | Allowed |
|------------|---------|
| View PM dashboard, lists, and detail | ✔ |
| Filter (upcoming / overdue / history / by charger) | ✔ |
| View PM history | ✔ |
| View schedules (task name, due date, checklist) | ✔ |
| View assigned technician(s) | ✔ |
| View completion photos and notes (read-only, on completed tasks) | ✔ |
| **Confirm** upcoming maintenance before scheduled work | ✔ |

Confirm is stored on `pm_task_occurrences` (`requestorConfirmedAt`, `requestorConfirmedById`) via `PmOccurrenceProvider.confirmOccurrenceForRequestor`. UI: **Confirm** on list cards and detail; confirmed tasks show **Confirmed**.

### Requestors may not

| Capability | Allowed |
|------------|---------|
| Complete PM | ✗ |
| Edit PM | ✗ |
| Assign PM | ✗ |
| Upload completion photos | ✗ |
| Modify checklist | ✗ |

**Primary UI:** More menu → Preventive Maintenance → `RequestorPmDashboardScreen`

Data path:

```
PmOccurrenceProvider.loadCompanyOccurrences(companyId)
  → PmInboxProvider.inbox
  → scopeRequestorPmWorkItems (asset filter)
  → UI
```

Asset visibility is client-side filtered to company-scoped assets from
`AssetProvider`, aligned with backend RLS.

## Requestor PM rules (hard constraints)

1. **Read-only PM execution** — requestors do not complete, edit, assign, or upload completion artifacts
2. **Confirm only** — the sole requestor write path is PM Confirm (`confirmOccurrenceForRequestor`); no other mutation from requestor PM screens
3. **No new domain logic** — filtering/scoping is presentation-only (`requestor_pm_work_item_scope.dart`)
4. **No bypass** — all list data from `PmInboxProvider` + existing filter utils
5. **Module hidden when flag OFF** — menu entry and screens show unavailable state

## Admin / legacy paths (unchanged)

- `PMTaskListScreen` — admin/manager legacy list (frozen)
- `CreatePMTaskScreen` — legacy create
- Web admin / React — schedule creation for Option A (see `FOR_REACT_PM_TASK_CREATION.md`)

## Enabling Option A in production

1. Set `ENABLE_PM_OCCURRENCES=true` in `scripts/defines.production.json` (example file defaults to `"true"`)
2. Validate: `node scripts/validate_production_defines.mjs`
3. Build: `./scripts/build_production.sh requestor ipa` and `./scripts/build_production.sh technician ipa`
4. Ensure React admin creates `pm_schedules` and generates occurrences
5. Verify RLS on `pm_task_occurrences` for technician assign + **requestor company read** + **requestor confirm**
   - Read RLS migration: `./scripts/db.sh run scripts/sql/migrate_requestor_pm_occurrences_read_rls.sql`
   - Confirm migration: `./scripts/db.sh run scripts/sql/migrate_requestor_pm_confirm.sql`
   - Verify read RLS: `./scripts/db.sh run scripts/sql/verify_requestor_pm_occurrences_read_rls.sql`
6. Run mobile QA: technician inbox, occurrence completion, requestor PM module (view + Confirm; no Complete)
7. Monitor debug validation warnings for cross-source ID collisions during migration

Set `"false"` only if Supabase has not yet been migrated to schedules/occurrences.

## Related docs

- `docs/FOR_REACT_PM_TASK_CREATION.md` — legacy `pm_tasks` schema
- `docs/requestor-db/12-ppm-preventive-maintenance.md` — requestor DB context
- `docs/QA_REQUESTOR_PPM_ENTERPRISE_AUDIT.md` — enterprise audit findings
- `packages/cmms_core/test/pm_option_a_phase1_test.dart` — Option A phase 1 spec

## Final state (post Session 10)

| Surface | Status |
|---------|--------|
| Technician unified PM inbox | ✔ |
| Occurrence detail + completion | ✔ |
| Requestor full read-only PM + Confirm | ✔ |
| Legacy PMTask | Preserved, isolated, frozen |
| UI merge via `PmWorkItem` | ✔ |
| Inbox validation hooks | ✔ (debug) |
| Centralized routing | ✔ |
