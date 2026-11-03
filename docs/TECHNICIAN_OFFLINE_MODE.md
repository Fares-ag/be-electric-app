# Technician offline: field-day MVP

**Date:** 2026-08-16 (Pass 4 — offline parity)  
**Package:** `packages/cmms_core/`

## As-implemented

| Area | Behavior |
|------|----------|
| Kill switch | `--dart-define=OFFLINE_MODE=false` → fail-fast; no enqueue; `processQueue` no-ops |
| Connectivity | `ConnectivityService` (+ `.instance` / GetIt same singleton) |
| Sync queue | `OfflineQueueService` coalesce, photo-before-WO, atomic WO/PM completion |
| WO Start / Complete / status | `updateWorkOrderOnlineOrQueue` inside `UnifiedDataService` |
| PM Start / Complete | `offline_pm_task_mutation.dart` + atomic `completePMTask` queue ops |
| Parts create | Online insert or enqueue via `resolveOfflineQueueService()` |
| Surface cache | WO/PM SharedPreferences snapshots per user (`technician_*_surface_cache_*`) |
| Asset disk cache | `HybridDamService` key `be_assets_disk_v1`; hydrate offline; prefetch on auth |
| Session purge | `SessionPurgeService.purgeOnSessionEnd()` on logout clears queue, surface, DAM disk |
| UX | `OfflineSyncGlobalBanner`, row badges via `OfflineSyncStatusProvider`, Sync queue screen |

## Architecture notes

- **Choke point:** `UnifiedDataService.updateWorkOrder` (not `WorkOrderProvider`) for WO offline enqueue.
- **Reactive UI:** `OfflineSyncStatusProvider` listens to `ConnectivityService` + `OfflineQueueService.queueRevision`.
- **Logout:** `AuthProvider.logout()` → `SessionPurgeService` → `CmmsDataCoordinator.purgeUserSession()` + queue/DAM/realtime teardown.
- **Reconnect:** `CmmsDataCoordinator` runs `processQueue()` then `refreshTechnicianSurface()` when connectivity returns.

## Airplane E2E checklist — Work orders

1. Sign in online; open assigned WO (cached in surface + asset disk).
2. Airplane mode → orange global banner.
3. Start Work → row shows **Pending sync** badge.
4. Complete with note + photo → staged photos snackbar; badge remains.
5. Create parts request → pending count increments in banner.
6. Force-quit; reopen offline → Sync queue still has ops; WO list from surface cache.
7. Restore network → ops flush; banner clears; cloud rows present.
8. With network: Start/Complete/parts write immediately (no double rows).

## PM offline scenarios

| Step | Expected |
|------|----------|
| Online: open assigned PM task | Checklist + asset name visible |
| Airplane: Start PM | Status → in progress locally; **Pending sync** badge on card |
| Airplane: complete checklist + photo | Atomic `completePMTask` queued; legacy photo/update ops coalesced |
| Kill app offline | PM task + queue survive via surface cache + SharedPreferences queue |
| Relaunch offline | PM inbox shows local state; banner shows pending count |
| Reconnect | Queue flushes; badge clears; server shows completed cycle |
| Logout (online or offline) | Queue cleared; surface + `be_assets_disk_v1` purged; no prior-user data |

## Kill / relaunch checklist

- [ ] Pending queue count unchanged after force-quit
- [ ] WO list renders from surface cache when offline at cold start
- [ ] PM tasks render from surface cache when offline at cold start
- [ ] Asset search / QR resolves from `be_assets_disk_v1` when offline
- [ ] Logout → login as different user shows empty lists (no leak)
- [ ] Logout clears sync queue screen (0 pending)
- [ ] Reconnect auto-flushes without manual "Sync now" (banner button still works)

## Tests

- `test/utils/offline_sync_utils_test.dart`
- `test/services/offline_queue_coalesce_test.dart`
- `test/services/pm_task_offline_flow_test.dart`

Run:

```bash
cd packages/cmms_core && flutter test test/utils/offline_sync_utils_test.dart test/services/offline_queue_coalesce_test.dart test/services/pm_task_offline_flow_test.dart
```

## Out of scope

Requestor/admin offline, parts approve/fulfill offline, PM schedule edits, interactive merge, SQLite.
