# Be Electric Requestor — PPM (PM Tasks) Enterprise QA Audit

> **Historical document — superseded (July 2026)**  
> This audit reflects the state **before PM Option A shipped** (29 June 2026). Its recommendation to **HIDE PM** and **wait for Option B** is **no longer current**.  
> **Current behavior:** Requestor read-only PM + Confirm is implemented when `ENABLE_PM_OCCURRENCES=true`. See `docs/PM_MIGRATION_GUIDE.md`, `docs/APP_STORE_REVIEW_NOTES.md`, and `docs/STORE_RELEASE.md` §3.4.  
> Retained for audit trail only — do not use for release decisions.

**App:** `apps/requestor_cmms` (`com.beelectric.cmms.requestorCmms`)  
**Shared package:** `packages/cmms_core` (`CmmsAppMode.requestor`)  
**Supabase project:** `sdhqjyjeczrbnvukrmny`  
**Audit date:** 29 June 2026  
**Scope:** Planned Preventive Maintenance (PPM) / `pm_tasks` visibility, data, security, and UX in the requestor app

---

## Executive summary

### Recommendation (historical): **HIDE for v1 ship — BUILD read-only PPM for v2**

> **Superseded:** PM Option A requestor module (read-only + Confirm) shipped post-audit. See current docs above.

**Product answers:**

| Question | Answer |
|----------|--------|
| **Should requestors see PM tasks today?** | **No** — not in product docs, permission matrix, or active navigation. CMMS docs list PM execution for **technicians only**. |
| **What works today?** | Nothing user-facing. Backend loads `pm_tasks` on login but RLS returns **0 rows** for requestors. Legacy PM code exists in **orphaned** `RequestorDashboardScreen` (wrong filter, UI never renders PM). |
| **What to build for v1 requestor PPM?** | **Option B: read-only schedule** — company-scoped SELECT RLS via `assets.companyId`, dedicated “Maintenance Schedule” screen (due date, status, asset, assigned tech name via RPC), no Start/Complete. **Not** notifications-only (no PM notification pipeline to requestor today). |

**Ship posture for requestor app overall:** Unaffected — requestors use maintenance **requests** (`work_orders`), support, analytics. **Do not market PPM** in requestor App Store copy until Option B ships.

**Sign-off:**

| Reviewer | PPM ready? | Notes |
|----------|------------|-------|
| Product owner | No | Choose hide vs read-only; no current UX |
| Release manager | Yes (hide) | No exposed broken PPM surface in live nav |
| Field-ops lead | No | Requestors cannot see preventive schedules |

---

## Scope & methodology

### In scope

Sections A–J: product definition, RLS, dashboard surfacing, asset linkage, notifications, analytics, security, reliability, tests, improvement backlog.

### Method

| Step | Result |
|------|--------|
| Code audit | All requestor + PM touchpoints traced (see sections) |
| `flutter analyze` `apps/requestor_cmms` | **0 issues** |
| `flutter analyze` `packages/cmms_core` | 2867 info-level lints, **0 errors** |
| `flutter test` `packages/cmms_core` | **184 passed, 4 skipped** — no requestor PPM tests |
| `./scripts/db.sh check` | OK |
| `./scripts/db.sh run scripts/sql/verify_requestor_backend.sql` | Shared infra OK |
| `./scripts/db.sh run scripts/sql/verify_technician_backend.sql` | PM technician UPDATE OK (T-001 fixed) |
| `./scripts/db.sh run scripts/sql/verify_requestor_ppm_backend.sql` | **`pm_requestor_read_policy: MISSING`** |

---

## Product decision matrix

| Option | Description | Effort | Recommendation |
|--------|-------------|--------|----------------|
| **A — Hide** | Remove/gate dead PM code; skip `loadPMTasks` in requestor mode | **S** | **Ship now** — aligns with docs & matrix |
| **B — Read-only PPM** | Company-scoped SELECT RLS + schedule screen + read-only detail | **M** | **v2** — high field-ops value |
| **C — Full PPM** | Requestor completes/signs PM | **L** | **Reject** — wrong role; technician owns execution |
| **D — Notifications only** | PM due alerts without in-app list | **M** | **Partial** — needs server notifications + prefs wiring |

---

## Feature matrix

| Area | Code | Backend | RLS | Product intent | Overall |
|------|------|---------|-----|----------------|---------|
| A. Product & scope | Partial | N/A | N/A | Hide | **Fail** (dead code) |
| B. Data model & RLS | Pass | Pass | **Fail** (no requestor SELECT) | Read-only future | **Fail** |
| C. Dashboard PPM | Dead code | N/A | N/A | Not in nav | **N/A** |
| D. Asset linkage | Partial | Pass | Would need join | Option B | **Partial** |
| E. Notifications | Partial | Partial | N/A | Not wired | **Fail** |
| F. Analytics | N/A | Loads unused | N/A | WO only | **Pass** (no PM shown) |
| G. Security | **Risk** | OK | OK (deny by default) | Hide actions | **Partial** |
| H. Reliability | Partial | Silent empty | OK | — | **Partial** |
| I. Tests | None | — | — | — | **Fail** |
| J. Improvements | Documented | — | — | — | **Delivered** |

---

## Findings (severity-sorted)

| ID | Severity | Area | Finding | Evidence |
|----|----------|------|---------|----------|
| R-PPM-001 | **Major** | RLS | **No requestor SELECT policy** on `pm_tasks` — `getAllPMTasks()` returns `[]` silently | Live policies: admin `*`, technician read/update assigned only. Verify: `pm_requestor_read_policy: MISSING` |
| R-PPM-002 | **Major** | Navigation | **`RequestorDashboardScreen` orphaned** — not in `RoleBasedNavigation` or overflow menu | `role_based_navigation.dart` → `RequestorMainScreen`; `requestor-db/11-overflow-menu.md` |
| R-PPM-003 | **Major** | Logic | Wrong filter: `pt.hasTechnician(currentUser.id)` on requestor dashboard | `requestor_dashboard_screen.dart` L193–195 — uses technician assignment check on requestor uid |
| R-PPM-004 | **Major** | UX | **`pmTasks` passed to `_buildQuickStats` / `_buildRecentActivity` but never rendered** — misleading dead code | Same file L333–464: only `workOrders` in UI |
| R-PPM-005 | **Major** | Security UX | **`PMTaskDetailScreen` shows Start/Pause/Complete to all roles** — no requestor gate; UPDATE would fail at RLS but UI is wrong | `pm_task_detail_screen.dart` L896–1009 — no `_isRequestor()` check on action block |
| R-PPM-006 | **Major** | Performance | Requestor login **loads all PM tasks** via `UnifiedDataService.loadPMTasks()` despite no UI need | `unified_data_service.dart` L398–406; called from `CmmsDataCoordinator` |
| R-PPM-007 | **Minor** | Notifications | Notification handler navigates to `PMTaskDetailScreen` via `firstWhere` — **throws** if PM not in cache | `requestor_dashboard_screen.dart` L803–805 (orphaned screen) |
| R-PPM-008 | **Minor** | Doc drift | `FOR_REACT_FLUTTER_USER_FLOW.md` §3 lists requestor capabilities **without PM** — **aligned** with hide recommendation | §3.1–3.3 |
| R-PPM-009 | **Minor** | Doc drift | `PMTaskListScreen` requestor branch shows **unassigned only** — unreachable + wrong product | `pm_task_list_screen.dart` L82–89 |
| R-PPM-010 | **Info** | Data | Live DB: **1 PM task**, unassigned, asset on **Pearl Qatar** — no requestor users on that company | Verify SQL company join |
| R-PPM-011 | **Info** | Tests | No widget/integration tests for requestor PPM | `packages/cmms_core/test/` |
| R-PPM-012 | **Info** | Analytics | PM loaded on `refreshAll()` but **unused** in `RequestorAnalyticsScreen` | `requestor-db/07-analytics.md` confirmed |

**Not a blocker for requestor ship:** RLS correctly **denies** PM data today — no data leak.

---

## RLS & backend gap analysis

### Live `pm_tasks` policies (29 Jun 2026)

| Policy | Command | Rule |
|--------|---------|------|
| `Admins can manage pm_tasks` | ALL | `get_my_role() IN ('admin','manager')` |
| `Technicians can read assigned pm_tasks` | SELECT | `auth.uid()::text = ANY(assignedTechnicianIds)` |
| `Technicians can update assigned pm_tasks` | UPDATE | Same (T-001) |
| **Requestor** | — | **None** |

### Requestor JWT SELECT test (logical)

- `SupabaseDatabaseService.getAllPMTasks()` → `from('pm_tasks').select()`  
- On error: catches exception, returns **`[]`** (`supabase_database_service.dart` L1244–1246)  
- **Result:** Requestor cache always empty; no user-visible error

### Company-scoped read (Option B simulation)

Live query `ppm_visible_if_company_scoped`: **0 PM rows** for all 3 requestor users’ companies (only PM is on `company-pearl-qatar`).

### Proposed migration (Option B — not applied)

See `docs/requestor-db/12-ppm-preventive-maintenance.md` for full SQL: requestor SELECT where `pm_tasks.assetId` joins `assets.companyId = users.companyId`.

---

## Cross-doc reconciliation

| Document | PM / requestor alignment |
|----------|--------------------------|
| `CMMS_FULL_DOCUMENTATION.md` §3 | Requestor: create requests, view own, analytics — **no PM** | ✅ Hide |
| `FOR_REACT_FLUTTER_USER_FLOW.md` §3 | Requestor flow **no PM** | ✅ Hide |
| `FOR_REACT_PM_TASK_CREATION.md` | PM create = technician Quick Create / admin | ✅ Not requestor |
| `REQUESTOR_DATABASE.md` | Previously omitted `pm_tasks` — **updated** with L section | Fixed in this audit |
| `requestor-db/11-overflow-menu.md` | Notes `RequestorDashboardScreen` legacy | ✅ |
| `QA_TECHNICIAN_ENTERPRISE_AUDIT.md` | Technician PM execution RLS fixed | N/A to requestor read |
| `TECHNICIAN_APP_FUNCTIONAL_REVIEW.md` | PM = technician tab | ✅ |

---

## Feature sections (A–J)

### A. Product & scope definition

- **User-facing purpose:** None in production requestor nav.
- **Product intent:** Requestors submit **corrective** maintenance (`work_orders`); **preventive** schedules are operational (technician/admin). Optional v2: **visibility only**.
- **Client stack:** Active shell = `RequestorMainScreen` only (`role_based_navigation.dart` L38–39).
- **Database ops:** Incidental `pm_tasks` SELECT on bootstrap (blocked).
- **RLS:** Deny by default — correct for hide strategy.
- **Findings:** R-PPM-002, R-PPM-003, R-PPM-004
- **Verification:** Login as requestor → confirm no PM menu/tab; grep navigation for `PMTask`.

### B. Data model & RLS (`pm_tasks`)

- **User-facing purpose:** N/A today.
- **Product intent:** Option B needs `assetId`, `nextDueDate`, `status`, `taskName`, assignment display.
- **Client stack:** `UnifiedDataProvider.pmTasks` ← `UnifiedDataService._pmTasks`
- **Database ops:** READ `getAllPMTasks`, stream `listenToPMTasks`
- **RLS:** **No requestor policy** — R-PPM-001
- **Findings:** No INSERT/UPDATE for requestor — correct. No `companyId` on table — join via `assets`.
- **Verification:** `./scripts/db.sh run scripts/sql/verify_requestor_ppm_backend.sql`

### C. Requestor dashboard PPM surfacing

- **User-facing purpose:** Would show stats/activity (never shipped).
- **Product intent:** Should not exist until Option B.
- **Client stack:** `RequestorDashboardScreen` (orphaned)
- **Findings:** R-PPM-002, R-PPM-003, R-PPM-004, R-PPM-007
- **Verification:** Confirm screen unreachable from `RequestorMainScreen` / menu.

### D. Asset / charger linkage

- **User-facing purpose:** Requestors pick chargers for **requests**; no PM schedule link.
- **Product intent:** Option B: show PM for same `assetId` / company chargers.
- **Client stack:** `CreateMaintenanceRequestScreen` → `assets` by `companyId`
- **Database ops:** READ `assets` — OK for requestor
- **RLS:** `Authenticated can read assets`
- **Findings:** **Info** — foundation for Option B exists; no UI link to `pm_tasks`
- **Verification:** SQL join sample in verify script

### E. Notifications & reminders

- **User-facing purpose:** In-app list (work-order oriented); PM types exist in enum.
- **Product intent:** Optional future: `pmTaskDue` / `pmTaskOverdue` to requestors for company assets.
- **Client stack:** `NotificationService` / `EnhancedNotificationService`; requestor list = **SharedPreferences only** (`requestor-db/08-notifications.md`)
- **Database ops:** `notifications` table unused by requestor UI; PM cron in `ONESIGNAL_SETUP.md` targets technicians
- **Findings:** R-PPM-007 (orphaned handler); no requestor PM notification path
- **Verification:** No PM rows in `notifications` table required for current app

### F. Analytics (requestor)

- **User-facing purpose:** WO stats for own requests.
- **Product intent:** No PM KPIs for requestor.
- **Client stack:** `RequestorAnalyticsScreen` — filters `workOrders` by `requestorId` only
- **Findings:** R-PPM-012 — PM loaded on refresh, unused
- **Verification:** Open Analytics → confirm no PM labels

### G. Security & privacy

- **User-facing purpose:** Protect PM operational data.
- **Product intent:** Least privilege — company-scoped read if Option B.
- **Findings:** R-PPM-005 — detail screen exposes technician actions; RLS prevents writes today
- **Privacy:** Read-only PM schedule (asset names, due dates) fits existing privacy policy maintenance data; no new collection type
- **App Store:** No change if PM hidden; if Option B, declare operational schedule data under User Content / App Functionality

### H. Reliability & UX

- **Findings:** R-PPM-006 wasted fetch; silent empty on RLS (`getAllPMTasks` swallows errors)
- **Realtime:** `listenToPMTasks` subscribed for all roles — empty stream for requestor
- **Verification:** Debug log: `Retrieved 0 PM tasks` on requestor login

### I. Test coverage

- **Findings:** R-PPM-011 — zero requestor PPM tests
- **Recommended:** Widget test read-only schedule; integration test RLS mock; guard `PMTaskDetailScreen` for requestor

### J. Improvements backlog

See [Improvement roadmap](#improvement-roadmap-p0p1p2) below.

---

## Role matrix (PM tasks)

| Action | Requestor (today) | Requestor (Option B) | Technician | Admin/Manager |
|--------|-------------------|----------------------|------------|---------------|
| See PM list in app | No (no nav + RLS) | Read-only, company assets | Assigned (+ unassigned pickup in list) | All |
| View PM detail | Orphan path only | Read-only detail | Full | Full |
| Start / complete PM | UI shown if reached; RLS blocks | **No** | Yes (assigned) | Yes |
| Create PM | No | **No** | Quick Create (RLS blocked) / admin | Yes |
| Receive PM notifications | No | Future | Partial (local/enhanced) | Yes |

---

## Improvement roadmap (P0/P1/P2)

### P0 — Before claiming requestor PPM (S)

| # | Epic | Tasks | Effort |
|---|------|-------|--------|
| 1 | **Hide (Option A)** | Remove or `#ifdef` PM load in requestor mode; delete/gate orphaned `RequestorDashboardScreen` PM code; add `readOnly` / role gate on `PMTaskDetailScreen` | **S** |

### P1 — Read-only PPM v1 (M)

| # | Epic | Tasks | Effort |
|---|------|-------|--------|
| 2 | **Backend** | Migration: `Requestors can read company pm_tasks` + verify SQL | **S** |
| 3 | **Flutter** | `RequestorPMScheduleScreen` — list by `companyId`/asset; read-only detail; overflow menu entry | **M** |
| 4 | **Data** | Optional RPC `get_technician_names_for_ids` (requestor cannot SELECT all users) | **S** |
| 5 | **Docs** | Update CMMS matrix + App Store if shipping | **S** |

### P2 — Enhancements (L)

| # | Epic | Tasks | Effort |
|---|------|-------|--------|
| 6 | Notifications | Server PM due for company assets → `notifications` + requestor prefs consumer | **L** |
| 7 | Asset detail | PM schedule section on charger detail from maintenance request flow | **M** |
| 8 | Tests | Widget + integration suite for requestor PPM | **M** |
| 9 | Skip PM fetch | `CmmsDataCoordinator` role-aware: skip `loadPMTasks` for requestor until Option B | **S** |

---

## Test execution log

```bash
# Static analysis
cd apps/requestor_cmms && flutter analyze
# → No issues found!

cd packages/cmms_core && flutter analyze
# → 2867 issues (style/info), 0 errors

# Tests
cd packages/cmms_core && flutter test
# → 184 passed, 4 skipped

# Database
./scripts/db.sh check
# → Connection OK

./scripts/db.sh run scripts/sql/verify_requestor_backend.sql
# → companies, RPCs, support, notifications policies OK

./scripts/db.sh run scripts/sql/verify_technician_backend.sql
# → pm_technician_update_policy: OK

./scripts/db.sh run scripts/sql/verify_requestor_ppm_backend.sql
# → pm_requestor_read_policy: MISSING
# → pm_tasks_row_count: 1 (unassigned)
# → requestor_users_with_company: 3
```

---

## Pre-release checklist (requestor PPM)

- [ ] **Product sign-off:** Hide (A) vs read-only (B) for next release
- [ ] **P0 if hiding:** Stop loading PM tasks in requestor bootstrap; remove dead dashboard PM code
- [ ] **P0 security:** Gate `PMTaskDetailScreen` actions by role (even if orphaned)
- [ ] **If Option B:** Apply company-scoped SELECT migration + seed PM on requestor company assets for QA
- [ ] **Do not** document PPM in requestor App Store features until Option B ships
- [ ] Add widget tests when implementing Option B

---

## Suggested follow-up tickets

### Epic: Requestor PPM — Hide dead code (P0)
- Skip `loadPMTasks` when `CmmsAppMode.requestor`
- Archive or delete PM sections in `RequestorDashboardScreen` or wire screen intentionally

### Epic: Requestor PPM — Read-only schedule (P1)
- SQL migration + `verify_requestor_ppm_backend.sql` green
- New screen + menu entry
- Read-only `PMTaskDetailScreen` mode

### Epic: Requestor PPM — Quality (P2)
- Integration tests with mocked Supabase
- PM due notifications for requestors (server + UI)

---

## References

- Feature doc: [docs/requestor-db/12-ppm-preventive-maintenance.md](requestor-db/12-ppm-preventive-maintenance.md)
- Verify: [scripts/sql/verify_requestor_ppm_backend.sql](../scripts/sql/verify_requestor_ppm_backend.sql)
- Master DB index: [docs/REQUESTOR_DATABASE.md](REQUESTOR_DATABASE.md)
- Orphan dashboard: [docs/requestor-db/11-overflow-menu.md](requestor-db/11-overflow-menu.md)
- Code: `packages/cmms_core/lib/screens/requestor/requestor_dashboard_screen.dart` (legacy PM)
- Active home: `packages/cmms_core/lib/screens/requestor/requestor_main_screen.dart`
