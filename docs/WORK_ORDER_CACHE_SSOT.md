# Work Order Cache — Single Source of Truth

## Current Flow (before refactor)

```
Supabase DB
    │
    ├─ REST (repository) ──► UnifiedDataService._workOrders  (page 0 + append)
    │
    └─ Realtime channel ──► WorkOrderProvider._realtimeWorkOrders
                                    │
                                    └── syncRealtimeWorkOrders() ──► overwrites service cache
```

### Cache layers (4 effective copies)

| Layer | Location | Role |
|-------|----------|------|
| Supabase | Postgres | Authoritative persistence (no in-app list cache) |
| Service | `UnifiedDataService._workOrders` | Paginated fetch, CRUD writes, full-list replace via `syncRealtimeWorkOrders` |
| Provider | `WorkOrderProvider._realtimeWorkOrders` | Parallel list after `_workOrdersCacheSeeded` |
| Getter switch | `_workOrdersCacheSeeded` | UI read from provider OR service depending on flag |

### Problems

1. **Dual lists** — provider and service both held work orders; `syncRealtimeWorkOrders` replaced the entire service list from the provider copy.
2. **Divergence** — CRUD updated both layers independently; `updateWorkOrder` in service did not upsert missing rows.
3. **Confusing seeding** — `seedFromService()` copied service → provider → synced back to service.
4. **Single listener** (WO channel) lived in provider, but merge logic was split across layers.
5. **Unused full-table stream** — `workOrdersStream` / `getWorkOrdersStream()` exposed but never subscribed (dead path).

---

## Proposed Flow (implemented)

```
Supabase DB
    │
    ├─ REST ──► UnifiedDataService._workOrders  ◄── CANONICAL CACHE
    │
    └─ Realtime channel ──► applyWorkOrderChange() ──► same _workOrders list
                                    │
                                    └── onChanged callback
                                              │
                                              ▼
                              WorkOrderProvider (derived view only)
                              populateWorkOrderReferences + dedupe
                              _populatedWorkOrdersCache (invalidate on change)
```

### Rules

1. **One canonical list**: `UnifiedDataService._workOrders`
2. **Incremental realtime merge**: `applyWorkOrderChange(event)` — no full-list replace
3. **One listener**: `UnifiedDataService.startWorkOrderRealtimeListener()`
4. **Provider is a view**: `_populatedWorkOrdersCache` is derived, invalidated on any canonical change
5. **No `syncRealtimeWorkOrders` in provider** — deprecated on service

---

## Migration Risks

| Risk | Mitigation |
|------|------------|
| UI stops updating on realtime | Callback wires service → provider `_onCanonicalWorkOrdersChanged` |
| Missing user/asset refs on realtime rows | `_buildWorkOrdersView()` triggers `recoverMissingReferences` |
| Reopen/update WO not in paginated cache | Service `updateWorkOrder` now upserts when missing |
| Double listener if re-init | `startWorkOrderRealtimeListener` guards with `_workOrderRealtimeListening` |
| Breaking callers of `syncRealtimeWorkOrders` | Method kept deprecated on service only |

---

## Files Changed

- `lib/utils/work_order_cache_sync.dart` — `applyWorkOrderChange()`
- `lib/services/unified_data_service.dart` — canonical realtime listener, `upsertWorkOrderInCache`, upsert on update
- `lib/providers/work_order_provider.dart` — removed `_realtimeWorkOrders`, derived view only
- `test/utils/work_order_cache_sync_test.dart` — merge tests

---

## Regression Checklist

- [ ] Initial load shows paginated work orders
- [ ] Scroll load-more appends without duplicates
- [ ] Realtime insert/update/delete reflects in list
- [ ] Create / update / delete / reopen from UI
- [ ] Detail screen `updateCachedWorkOrder` syncs list badge
- [ ] Sign-out clears cache; re-login reloads
- [ ] `flutter test` passes
