# C. My Requests / Status / History

## User-facing purpose

Requestor views all maintenance requests they submitted, with status filters, pull-to-refresh, and live updates.

## Screens & entry points

| Screen | Path |
|--------|------|
| My Requests (from home menu) | `lib/screens/requestor/requestor_status_screen.dart` |
| Dashboard tabs | `lib/screens/requestor/requestor_dashboard_screen.dart` (My Requests, History) |

## Client stack

```
RequestorStatusScreen
  → UnifiedDataProvider.loadRequestorWorkOrders(user.id)
    → UnifiedDataService.loadWorkOrdersForRequestor
      → SupabaseWorkOrderRepository.getWorkOrdersByRequestor
        → SupabaseDatabaseService.getWorkOrdersByRequestor

RequestorDashboardScreen
  → UnifiedDataProvider.refreshAll / loadMoreWorkOrders
    → getWorkOrdersPage (paginated SELECT)
  → Client filter: wo.requestorId == currentUser.id

Realtime (both, via CmmsDataCoordinator after login)
  → WorkOrderProvider.startRealtimeListeners
    → RealtimeSupabaseService.listenToWorkOrderChanges
      → postgres_changes on public.work_orders
```

| Layer | File |
|-------|------|
| Coordinator | `lib/providers/cmms_data_coordinator.dart` |
| Realtime | `lib/services/realtime_supabase_service.dart` |
| Cache merge | `lib/utils/work_order_cache_sync.dart` |

## Database operations

| Operation | Target | Method | Key fields |
|-----------|--------|--------|------------|
| List (status screen) | `work_orders` | SELECT `.eq('requestorId', id).order('createdAt', desc)` | `requestorId` |
| List (dashboard) | `work_orders` | SELECT `.order('createdAt').range(from, to)` page size 30 | — |
| Single refresh | `work_orders` | SELECT `.eq('id').single()` | `id` |
| Realtime | `work_orders` | Supabase Realtime INSERT/UPDATE/DELETE | full row payload |

## Table schema

Uses full `work_orders` row (see [02-create-maintenance-request.md](02-create-maintenance-request.md)). Display fields include `ticketNumber`, `status`, `priority`, `problemDescription`, `createdAt`, `metadata.photoPaths`.

## Storage

Read-only: photo URLs from row / `metadata` rendered via `AuthenticatedImage`.

## RLS / permissions (requestor)

Live policy **Requestors can read own work orders**:

```sql
"requestorId" = auth.uid()::text
```

- Status screen: server filter + RLS (defense in depth).
- Dashboard: **relies primarily on RLS** then client-filters `requestorId` (paginated query has no server-side requestor filter).
- Realtime: only delivers rows visible under JWT policies.

Requires authenticated session (`_isAuthenticated` in DB service).

## Admin/back-office notes

Admin sees same rows via `Admins can read all work orders` (`get_my_role()` admin/manager).

## Failure modes & troubleshooting

| Symptom | Cause |
|---------|-------|
| Empty list but submits work | `requestorId` ≠ `auth.uid()::text` on inserted rows |
| Dashboard missing old WOs | Pagination loads latest 30 globally; client filter may exclude |
| Stale status | Realtime not connected; pull to refresh |

## Verification SQL

```sql
SELECT id, "ticketNumber", status, "requestorId", "createdAt"
FROM work_orders
WHERE "requestorId" = '<requestor-user-id>'
ORDER BY "createdAt" DESC LIMIT 20;

-- Realtime publication
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime' AND tablename = 'work_orders';
```
