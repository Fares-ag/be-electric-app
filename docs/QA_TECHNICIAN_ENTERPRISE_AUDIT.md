# Be Electric Tech — Enterprise QA Audit

**App:** `apps/technician_cmms` (`com.beelectric.cmms.technicianCmms`)  
**Shared package:** `packages/cmms_core` (`CmmsAppMode.technician`)  
**Supabase project:** `sdhqjyjeczrbnvukrmny`  
**Audit date:** 25 June 2026  
**Auditor method:** Code trace + static analysis + automated tests + live DB (`./scripts/db.sh`)

---

## Executive summary

### Ship recommendation: **NO-SHIP** (TestFlight / production)

Core technician workflows are implemented in Flutter and auth/bootstrap are sound, but **live Supabase RLS blocks two production-critical paths**:

1. **PM task start/complete** — technicians have SELECT on assigned `pm_tasks` but **no UPDATE policy**.
2. **Parts requests** — `inventory_items` is **admin/manager-only**; the parts picker loads zero rows for technicians.

Additional **Major** issues: 5 work orders reference deleted/unknown technician IDs (field users see empty assigned lists), work order completion requires **both** requestor and technician signatures (impractical on-site), dashboard vs work-order list scope mismatch, PM Tasks tab still renders a nested AppBar, and Quick Create exposes admin-only actions to technicians.

**What works today (with valid assignment data):** login/session restore, role routing, assigned work order read/update (RLS verified), work order start/pause/complete UI (if signatures provided), asset QR read, analytics scoping, profile/legal links, release build pipeline.

**Sign-off status:**

| Reviewer | Ready? | Blocker |
|----------|--------|---------|
| Release manager | No | RLS gaps + orphan WO assignments |
| Security reviewer | Conditional | No auth bypass; RLS is strict (sometimes too strict) |
| Field-ops lead | No | PM completion + parts + empty assigned WOs |

---

## Scope & methodology

### In scope

Sections A–O from the audit brief: bootstrap/auth, shell, dashboard, work orders, completion, PM tasks, parts, QR/assets, analytics, notifications, profile/legal, manager/admin in tech build, security/privacy, reliability/UX, store release.

### Method

| Step | Command / action | Result |
|------|------------------|--------|
| Code audit | Traced Screen → Provider → Service → Repository in `packages/cmms_core` | See feature sections |
| Static analysis | `flutter analyze` in `apps/technician_cmms`, `packages/cmms_core` | Tech app: **0 issues**; core: **2867 info-level lints**, **0 errors** |
| Unit/widget tests | `flutter test` in `packages/cmms_core` | **184 passed, 4 skipped** |
| DB connectivity | `./scripts/db.sh check` | **OK** |
| Shared infra verify | `./scripts/db.sh run scripts/sql/verify_requestor_backend.sql` | RPCs OK; companies/assets present |
| Technician verify | `./scripts/db.sh run scripts/sql/verify_technician_backend.sql` | PM UPDATE policy **MISSING**; inventory tech read **MISSING**; 5 orphan WO rows |
| Live RLS | `pg_policy` queries via `./scripts/db.sh query` | Documented per table |
| Doc reconciliation | Compared to listed docs | Conflicts flagged below |

### Out of scope

- Manual device QA on physical hardware (simulator login confirmed in prior session)
- App Store Connect submission (checklist reviewed from repo only)
- React admin parity testing

---

## Feature matrix

| Area | Code | Backend deployed | RLS allows | Overall |
|------|------|------------------|------------|---------|
| A. Bootstrap & auth | Pass | Pass | Pass | **Pass** |
| B. Technician shell | Partial | N/A | N/A | **Partial** |
| C. Dashboard | Partial | Pass | Pass | **Partial** |
| D. Work orders | Pass | Pass | Pass* | **Partial*** |
| E. WO completion | Pass | Pass | Pass* | **Partial*** |
| F. PM tasks | Pass | Pass | **Fail** | **Fail** |
| G. Parts requests | Pass | Pass | **Fail** | **Fail** |
| H. QR / assets | Pass | Pass | Pass | **Pass** |
| I. Analytics | Pass | Pass | Pass | **Pass** |
| J. Notifications | Pass | Partial | Pass | **Partial** |
| K. Profile / legal | Pass | Pass | Pass | **Pass** |
| L. Manager/admin | Pass | Pass | Pass | **Pass** |
| M. Security & privacy | Pass | Partial | Partial | **Partial** |
| N. Reliability / UX | Partial | N/A | N/A | **Partial** |
| O. Store release | Pass | N/A | N/A | **Partial** |

\*Assigned work orders only; 5 rows have orphan `assignedTechnicianIds` → invisible to all live technicians.

---

## Findings (severity-sorted)

| ID | Severity | Area | Finding | Evidence |
|----|----------|------|---------|----------|
| T-001 | **Blocker** | PM tasks | No RLS UPDATE policy for assigned technicians — start/complete/status changes fail at Postgres | Live: only `Technicians can read assigned pm_tasks` (r) + `Admins can manage pm_tasks` (*). Code: `SupabaseDatabaseService.updatePMTask` → `.from('pm_tasks').update()` |
| T-002 | **Blocker** | Parts | `inventory_items` has only `Admins manage inventory` — technicians cannot SELECT catalog | Live policy query; `PartsRequestScreen` reads `UnifiedDataProvider.inventoryItems` |
| T-003 | **Major** | Work orders | 5 WOs assigned to UUID `14a37af3-...` not in `users` — no live technician sees them | `./scripts/db.sh query` orphan count = 5; tech users `fares@gmail.com`, `faroos4848@gmail.com` have different IDs |
| T-004 | **Major** | WO completion | Both **requestor** and **technician** signatures required to submit — field tech often alone | `work_order_completion_screen.dart` lines 158–176 |
| T-005 | **Major** | PM Quick Create | Technicians offered “Create PM Task” but INSERT blocked (admin-only `*` on `pm_tasks`) | `technician_main_screen.dart` Quick Create; live RLS |
| T-006 | **Major** | Dashboard vs list | Dashboard counts assigned-only; WO list includes `requestorId == self` | `getWorkOrdersByTechnician` vs `WorkOrderListScreen` filter |
| T-007 | **Minor** | Shell UX | Double AppBar on **PM Tasks** tab (WO tab fixed via `showAppBar: false`) | `PMTaskListScreen` still builds own `AppBar`; `TechnicianMainScreen` has parent AppBar |
| T-008 | **Minor** | Permissions UX | “Setup General Assets” visible in debug (`ReleaseSafety.showDevTools`); hidden in release | `release_safety.dart`, `technician_main_screen.dart` |
| T-009 | **Minor** | QR navigation | “View Tasks” after scan pushes full-screen route — leaves bottom nav | Documented in `TECHNICIAN_APP_FUNCTIONAL_REVIEW.md` |
| T-010 | **Info** | Doc drift | `FOR_REACT_FLUTTER_USER_FLOW.md` §4 claims parts RLS allows read for assigned-WO requests; live is `requestedBy` only | Doc vs `pg_policy` on `parts_requests` |
| T-011 | **Info** | Doc drift | `TECHNICIAN_APP_FUNCTIONAL_REVIEW.md` §2.6 cites `qauto_cmms` imports in PartsRequestScreen — **fixed** (uses `cmms_core`) | `parts_request_screen.dart` imports |
| T-012 | **Info** | Tests | No widget/integration tests for technician screens (completion, PM, parts, main shell) | `packages/cmms_core/test/` grep |
| T-013 | **Info** | Data | 0 PM tasks with assignments in live DB — PM tab untestable end-to-end without seed data | Live query |
| T-014 | **Info** | Config | Debug builds embed Supabase URL/key defaults in `AppConfig` — release requires `--dart-define` | `app_config.dart` lines 54–72 |
| T-015 | **Info** | Version | `pubspec.yaml` at `1.0.0+1` — confirm bump before store | `apps/technician_cmms/pubspec.yaml` |

---

## RLS & backend gap analysis

### Live policies (queried 25 Jun 2026)

| Table | Technician SELECT | Technician INSERT | Technician UPDATE | Gap |
|-------|-------------------|-------------------|-------------------|-----|
| `work_orders` | `auth.uid()::text = ANY(assignedTechnicianIds)` | If `requestorId = uid` (technician-created WOs) | Same array check | Orphan IDs in data |
| `pm_tasks` | Assigned array contains uid | **Denied** (admin `*` only) | **Denied** | **T-001, T-005** |
| `parts_requests` | `requestedBy = uid` | `requestedBy = uid` | — | OK for own requests |
| `inventory_items` | **Denied** | **Denied** | **Denied** | **T-002** |
| `assets` | `true` (authenticated) | — | — | OK |
| `users` | `id = uid` | — | — | OK |
| `notifications` | `userId = uid` | `userId = uid` | `userId = uid` | OK |
| `storage.objects` | `files` bucket select | `files` insert/update | — | OK for photos |

### Recommended SQL fixes (proposals — not applied)

```sql
-- T-001: Allow assigned technicians to update pm_tasks
CREATE POLICY "Technicians can update assigned pm_tasks"
ON pm_tasks FOR UPDATE
USING (auth.uid()::text = ANY(COALESCE("assignedTechnicianIds", ARRAY[]::text[])))
WITH CHECK (auth.uid()::text = ANY(COALESCE("assignedTechnicianIds", ARRAY[]::text[])));

-- T-002: Allow authenticated read of inventory (or company-scoped variant)
CREATE POLICY "Authenticated can read inventory"
ON inventory_items FOR SELECT
USING (true);  -- tighten to company scope if column exists
```

Data fix for T-003: reassign or clear `assignedTechnicianIds` referencing missing users.

---

## Security & privacy

| Check | Status | Notes |
|-------|--------|-------|
| Auth required for domain data | Pass | `CmmsDataCoordinator` initializes streams on `signedIn` |
| Requestor blocked in tech app | Pass | `WrongAppRoleScreen` via `app_role_policy.dart` |
| RLS enforces least privilege | Pass (strict) | Over-restriction causes functional failures (T-001, T-002) |
| Secrets in repo | Pass | Production via `defines.production.json`; debug defaults in `AppConfig` only |
| `users.id` = `auth.uid()::text` | Pass | 0 auth/public mismatches in live DB |
| Privacy policy accuracy | Pass | Signatures, completion photos, no GPS — matches `docs/privacy_policy.md` |
| App Store privacy checklist (Tech) | Partial | Declare signatures + completion photos; push N/A; manual Supabase DPA confirmation |
| Account deletion path | Pass | Profile → mailto support (`user_profile_screen.dart`) |
| iOS permissions | Pass | Camera + Photo Library only (`Info.plist`) |
| OneSignal / push removed | Pass | `onesignal_push_service.dart` deleted per git status |

---

## Test execution log

```bash
# DB
./scripts/db.sh check
# → Connection OK

./scripts/db.sh run scripts/sql/verify_requestor_backend.sql
# → companies OK, RPCs OK, assets present

./scripts/db.sh run scripts/sql/verify_technician_backend.sql
# → pm_technician_update_policy: MISSING
# → inventory_technician_read_policy: MISSING
# → wo_orphan_technician_ids: DATA_ISSUE (5 rows)

./scripts/db.sh query "SELECT id, email, role FROM users WHERE role IN ('technician','admin')"
# → beelectric@q-auto.com (admin), fares@gmail.com, faroos4848@gmail.com (technicians)

# Static analysis
cd apps/technician_cmms && flutter analyze
# → No issues found

cd packages/cmms_core && flutter analyze
# → 2867 issues (style/info), 0 errors

# Tests
cd packages/cmms_core && flutter test
# → 184 passed, 4 skipped
```

---

## Feature sections (A–O)

### A. Bootstrap & auth

- **User-facing purpose:** Launch app, restore session, sign in, route by role.
- **Client stack:** `apps/technician_cmms/lib/main.dart` → `runTechnicianApp()` → `initializeCmms()` → `BeElectricApp(technician)` → `AuthWrapper` → `RoleBasedNavigation` → `AuthProvider` / `SupabaseAuthService` / `CmmsRepositories.users`
- **Database ops:** READ `users` via RPC `get_user_by_email`; WRITE `users` via `insert_user` (auto-create path, normally disabled for technicians); Supabase Auth sign-in/out
- **RLS expectation vs live:** `users.id = auth.uid()::text` — **aligned** (0 mismatches)
- **Findings:** **Info** — Pre-login realtime “permission denied” expected; bootstrap defers heavy fetches until `signedIn` (`cmms_bootstrap.dart` comment lines 76–80)
- **Verification:** Cold start → login as `fares@gmail.com`; confirm `RoleBasedNavigation` → `TechnicianMainScreen`; SQL: RPC existence in verify script

### B. Technician main shell

- **User-facing purpose:** Bottom nav: Dashboard, Work Orders, PM Tasks, Analytics; Quick Create; profile menu.
- **Client stack:** `technician_main_screen.dart` → embedded list screens / analytics
- **Database ops:** None directly (reads via providers)
- **RLS:** N/A
- **Findings:** **Minor** T-007 double AppBar on PM tab; **Minor** T-008 seed assets in debug menu; **Major** T-005 Quick Create PM Task for all roles
- **Verification:** Switch tabs; confirm single AppBar on Dashboard and Work Orders; PM Tasks shows duplicate titles

### C. Dashboard

- **User-facing purpose:** Assigned WO/PM counts, Request Parts, View Work Orders, Scan QR.
- **Client stack:** `TechnicianMainScreen` → `UnifiedDataProvider.getWorkOrdersByTechnician` / `getPMTasksByTechnician`
- **Database ops:** READ via realtime cache populated from `work_orders`, `pm_tasks` streams
- **RLS:** Assigned-array policies
- **Findings:** **Major** T-006 stat cards vs list scope mismatch
- **Verification:** Compare dashboard count to Work Orders tab; create self-requested WO and observe list +1, stat unchanged

### D. Work orders (technician view)

- **User-facing purpose:** List/filter assigned (and self-created) WOs; open detail; start/pause/complete.
- **Client stack:** `WorkOrderListScreen(isTechnicianView: true, showAppBar: false)` → `WorkOrderDetailScreen` → `UnifiedDataProvider` → `UnifiedDataService` → `SupabaseDatabaseService`
- **Database ops:** READ/UPDATE `work_orders`; filter client-side + RLS
- **RLS:** Read/update assigned — **live OK**; requestor update path for self-created WOs
- **Findings:** **Major** T-003 orphan assignments; **Partial** pass otherwise
- **Verification:** Assign WO to live technician UUID; confirm visibility; attempt start → inProgress update

### E. Work order completion

- **User-facing purpose:** Photos, signatures, corrective actions, costs; mark completed.
- **Client stack:** `WorkOrderCompletionScreen` → `updateWorkOrder` → storage upload `work_orders/completion_photos`
- **Database ops:** UPDATE `work_orders` columns + `metadata.completionPhotoPaths`; Storage INSERT `files`
- **RLS:** UPDATE assigned — **OK** if technician in `assignedTechnicianIds`
- **Findings:** **Major** T-004 dual signature requirement; photo upload continues on failure (orange snackbar)
- **Verification:** Complete assigned WO; confirm `status=completed`, signatures persisted; test with only technician signature (should block)

### F. PM tasks

- **User-facing purpose:** List assigned PM tasks; start; complete with checklist/photos.
- **Client stack:** `PMTaskListScreen` → `PMTaskDetailScreen` → `PMTaskCompletionScreen` → `updatePMTask`
- **Database ops:** READ/UPDATE `pm_tasks`; Storage `pm_tasks/completion_photos`
- **RLS:** SELECT assigned — **OK**; UPDATE — **MISSING (Blocker T-001)**
- **Findings:** **Blocker** T-001; **Info** T-013 no assigned PM data in DB
- **Verification:** Assign PM task to technician; start/complete → expect Postgres permission error until policy added

### G. Parts requests

- **User-facing purpose:** Request parts against an assigned work order.
- **Client stack:** Dashboard → WO picker → `PartsRequestScreen` → `PartsRequestService` → `SupabaseDatabaseService.createPartsRequest`
- **Database ops:** INSERT/SELECT `parts_requests`; READ `inventory_items` for picker
- **RLS:** Parts INSERT/SELECT own — **OK**; inventory SELECT — **MISSING (Blocker T-002)**
- **Findings:** **Blocker** T-002; doc conflict T-010
- **Verification:** Open Request Parts → inventory dropdown empty for technician

### H. QR scan & assets

- **User-facing purpose:** Scan asset QR; view related WOs; navigate to filtered list.
- **Client stack:** `MobileQRScannerWidget` → asset lookup via `UnifiedDataProvider`
- **Database ops:** READ `assets` (authenticated read all)
- **RLS:** **OK**
- **Findings:** **Minor** T-009 navigation leaves bottom nav
- **Verification:** Scan known asset QR; confirm asset details; tap View Tasks

### I. Analytics

- **User-facing purpose:** Technician-scoped KPIs and charts.
- **Client stack:** `ConsolidatedAnalyticsDashboard(isTechnicianView: true)` → filters to assigned WOs/PM tasks
- **Database ops:** READ cached domain data (pagination: `loadMoreWorkOrders` on list, not all analytics slices)
- **RLS:** Inherited from cache population
- **Findings:** **Info** — global cache pagination may under-count in edge cases (same as requestor audit)
- **Verification:** Compare KPI totals to assigned WO count for test user

### J. Notifications

- **User-facing purpose:** In-app notification list/badge.
- **Client stack:** `NotificationService` / `EnhancedNotificationService` → Supabase `notifications` + SharedPreferences fallback
- **Database ops:** READ/INSERT/UPDATE `notifications` where `userId = uid`
- **RLS:** **OK**
- **Findings:** **Info** — No push/OneSignal; pre-login stream errors expected/noisy in logs only
- **Verification:** Trigger parts request → check manager notification insert (admin path)

### K. Profile, legal, logout

- **User-facing purpose:** View profile, open privacy/support URLs, request deletion, sign out.
- **Client stack:** `UserProfileScreen` → `legal_links.dart` / `AppConfig` URLs
- **Database ops:** READ `companies` for company name
- **RLS:** **OK**
- **Findings:** **Pass** — release requires `PRIVACY_POLICY_URL`, `SUPPORT_URL`, `SUPPORT_EMAIL` dart-defines
- **Verification:** Profile → legal links open; deletion dialog opens mail client

### L. Manager / admin in technician build

- **User-facing purpose:** Same binary serves manager/admin with full admin shell.
- **Client stack:** `RoleBasedNavigation` → `AdminMainScreen` for manager/admin roles
- **Database ops:** Broader RLS via `get_my_role()` admin/manager policies
- **RLS:** **OK** for privileged roles
- **Findings:** **Info** — No `WebAppRedirectScreen` in codebase; admin stays in Flutter admin shell
- **Verification:** Login as `beelectric@q-auto.com` → `AdminMainScreen`

### M. Security & compliance

See [Security & privacy](#security--privacy) above.

### N. Reliability & UX

- **User-facing purpose:** Graceful errors, realtime lifecycle, loading/empty states.
- **Client stack:** `user_facing_errors.dart`, `CmmsDataCoordinator` sign-in/out
- **Findings:** **Partial** — empty states exist; RLS failures surface as generic errors; iOS OneDrive path handled by `prepare_ios_build_dir.sh technician_cmms`
- **Verification:** Airplane mode → user-facing snackbars; sign out → cache cleared (`_handleSignedOut`)

### O. Store release readiness

- **User-facing purpose:** Production IPA/AAB with legal/Supabase defines.
- **Client stack:** `scripts/build_production.sh technician ipa|appbundle`
- **Findings:** **Partial** — pipeline exists; requires `scripts/defines.production.json`; version `1.0.0+1`; `ExportOptions.plist` present
- **Verification:** `./scripts/setup_production_defines.sh` then `./scripts/build_production.sh technician ipa` (not run in this audit)

---

## Role matrix

| Capability | technician | manager | admin | requestor (wrong app) |
|------------|------------|---------|-------|------------------------|
| Tech app login | Yes | Yes | Yes | Blocked (`WrongAppRoleScreen`) |
| `TechnicianMainScreen` | Yes | No | No | — |
| `AdminMainScreen` | No | Yes | Yes | — |
| Start/pause/complete WO | Yes* | Yes | Yes | No |
| WO cancel/reopen | No** | Per admin UI | Per admin UI | Yes (own WOs, requestor app) |
| PM start/complete | Blocked RLS | OK | OK | N/A |
| Create PM task (Quick Create) | Blocked RLS | OK | OK | N/A |
| Request parts | Blocked inventory RLS | OK | OK | N/A |
| Seed general assets | Debug only | Debug only | Debug only | N/A |
| Analytics (scoped) | Assigned | Global (admin shell) | Global | N/A |

\*Requires valid `assignedTechnicianIds` or self as requestor on own WO.  
\*\*Cancel/reopen UI gated by `_isRequestor()` in `WorkOrderDetailScreen`.

Source: `role_based_navigation.dart`, `work_order_detail_screen.dart`, live RLS.

---

## Cross-doc reconciliation

| Document | Alignment |
|----------|-----------|
| `TECHNICIAN_APP_FUNCTIONAL_REVIEW.md` | Mostly accurate; §2.1 dashboard mismatch still open; §2.2 double AppBar **partially fixed** (WO only); §2.6 Parts imports **fixed** |
| `FOR_REACT_FLUTTER_USER_FLOW.md` §4 | Parts RLS claim **overstates** technician read scope (T-010) |
| `FOR_REACT_WORK_ORDER_COMPLETION_DATA.md` | **Aligned** with `WorkOrderCompletionScreen` fields and storage paths |
| `FOR_REACT_PM_TASK_CREATION.md` | **Aligned** on INSERT path; RLS blocks technician create (T-005) |
| `REQUESTOR_DATABASE.md` | Shared tables accurate; technician-specific gaps in `technician-db/TECHNICIAN_DATABASE.md` |
| `app_store_privacy_checklist.md` | **Aligned** for Tech app data types |
| `privacy_policy.md` | **Aligned** (signatures, photos, no GPS) |

---

## Pre-release checklist (P0 before TestFlight)

- [ ] **T-001** Add `pm_tasks` UPDATE policy for assigned technicians (migration + verify script)
- [ ] **T-002** Add `inventory_items` SELECT for authenticated technicians (or company-scoped)
- [ ] **T-003** Reassign/clean 5 work orders with orphan `assignedTechnicianIds`
- [ ] **T-004** Product decision: make requestor signature optional for technician-only completion (or capture later)
- [ ] **T-005** Hide “Create PM Task” from technician Quick Create **or** add technician INSERT policy
- [ ] Seed at least one PM task assigned to a live technician for QA
- [ ] Run `./scripts/build_production.sh technician ipa` with production defines
- [ ] Bump `version` in `apps/technician_cmms/pubspec.yaml`

---

## Suggested follow-up tickets

### Epic: Backend RLS (P0)

- Add technician UPDATE on `pm_tasks`
- Add technician SELECT on `inventory_items`
- Optional: parts_requests SELECT for requests linked to assigned WOs
- Data migration: fix orphan technician IDs on work orders

### Epic: Technician UX (P1)

- Add `showAppBar: false` to `PMTaskListScreen` when embedded
- Align dashboard stats with WO list scope (or label “Assigned” clearly)
- Restrict Quick Create menu by role
- QR “View Tasks” → switch tab + filter instead of push

### Epic: Completion workflow (P1)

- Requestor signature optional / deferred for field completion
- Widget tests for `WorkOrderCompletionScreen`, `PMTaskCompletionScreen`

### Epic: QA & docs (P2)

- Technician integration tests (login → assigned WO → complete)
- Update `FOR_REACT_FLUTTER_USER_FLOW.md` parts RLS section
- Refresh `TECHNICIAN_APP_FUNCTIONAL_REVIEW.md` AppBar status

---

## References

- Code entry: `apps/technician_cmms/lib/main.dart`
- Role routing: `packages/cmms_core/lib/widgets/role_based_navigation.dart`
- Backend verify: `scripts/sql/verify_technician_backend.sql`
- DB mapping: `docs/technician-db/TECHNICIAN_DATABASE.md`
