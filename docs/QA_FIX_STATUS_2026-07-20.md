# QA fix status — 2026-07-20 (updated Pass 3 residual)

Baselines: Flutter `origin/monorepo` @ `a9b1e4a`, Web `origin/main` @ `b19eb17`.  
Local Flutter WIP ~366 files (GetIt/domain + offline). **Store truth = origin HEAD.**

| ID | Status | Notes |
|----|--------|-------|
| BE-QA-001 | **Fixed (code)** | Deactivate bans Auth, global signOut, drops `admin_users`; `requireAdmin` checks `isActive`; migration makes `get_my_role` NULL when inactive — **live apply pending** |
| BE-QA-002 | **Fixed (code)** | API + RPC: only `is_true_admin()` may assign `role=admin` — **live apply pending** |
| BE-QA-003 | **Fixed (migration draft)** | Requestor company-scoped assets/companies — **live apply pending** |
| BE-QA-004 | **Fixed** | UPDATE payload + no swallow + EnhancedNotification + fulfill-only decrement |
| BE-QA-005 | **Partial** | Trees mirrored + `MIGRATION_APPLY_ORDER.md`; orphan→occurrences still TODO |
| BE-QA-006 | **Documented risk** | WIP DI ≠ HEAD; do not dump GetIt/domain to store builds |
| BE-QA-007 | **Fixed** | Auth create rollback on profile failure |
| BE-QA-008 | **Fixed** | Delete profile then Auth |
| BE-QA-009 | **Fixed** | `createFallbackUser` gated to `NODE_ENV===development` |
| BE-QA-010 | **Fixed** | `loadRequestorWorkOrders` / `getWorkOrdersByRequestor` |
| BE-QA-011 | **Fixed** | Tech list assignment-only |
| BE-QA-013 | **Partial** | Proxy trims keys; ops must align Vercel↔Edge secrets |
| BE-QA-014 | **Fixed (migration draft)** | files INSERT path prefixes — **live apply pending** |
| BE-QA-OFF-001 | **Fixed (WIP)** | SyncQueue wired via `UnifiedDataService` + parts create; not on `a9b1e4a` tip |
| BE-QA-OFF-002 | **Fixed** | via BE-QA-004 |
| BE-QA-OFF-003 | **Fixed (WIP)** | Prefs fallback sets `lastListFromCache` / `lastListError`; parts UI snackbar |
| BE-QA-OFF-004 | **Fixed (WIP)** | Offline/network → enqueue; `OFFLINE_MODE=false` fail-fast |
| BE-QA-OFF-005 | **Fixed (WIP)** | Banner + Sync queue screen + Pending sync chips |

## Prod SQL you must approve

```bash
# From Be-electric-1 (preferred SSOT) after review:
# supabase db push   # or Dashboard SQL for 20260720160000_security_role_tenant_storage.sql

# Or Flutter:
./scripts/db.sh run scripts/sql/migrate_security_role_tenant_storage.sql
```

Then run verify queries in `docs/MIGRATION_APPLY_ORDER.md`.

## Residual risk

- Offline MVP + OFF-003 are **local WIP only** until a surgical commit (see `TECHNICIAN_OFFLINE_MODE.md` file list).
- Clean HEAD cherry-pick needs UDS adapted to `.instance` vs GetIt/`CmmsRepositories` baseline.
- Storage path policy may break unexpected upload prefixes.
- Orphan scrub still misses `pm_task_occurrences` assignees.
- Human: push secrets, device smoke, apply migrations.
