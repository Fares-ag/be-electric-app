# G. Analytics

## User-facing purpose

Requestor sees summary stats (counts, durations) for their maintenance requests.

## Screens & entry points

| Screen | Path |
|--------|------|
| Analytics | `lib/screens/requestor/requestor_analytics_screen.dart` |

Entry: overflow menu → Analytics (`requestor_more_menu.dart`).

## Client stack

```
RequestorAnalyticsScreen
  → Consumer<UnifiedDataProvider>
  → Filters: workOrders.where(wo => wo.requestorId == currentUser.id)
  → Asset names: unifiedProvider.assets
  → Pull-to-refresh: unifiedProvider.refreshAll()
    → CmmsDataCoordinator → UnifiedDataService.refreshAll
      → getWorkOrdersPage(page:0, pageSize:30), getAllAssets(), …
```

| Utility | File |
|---------|------|
| Duration calc | `lib/utils/work_order_duration.dart` |

## Database operations

| Operation | Target | Method | Key fields |
|-----------|--------|--------|------------|
| Display | In-memory cache | — | Filtered by `requestorId` |
| Refresh READ | `work_orders` | SELECT paginated `.order('createdAt').range(0,29)` | — |
| Refresh READ | `assets` | SELECT all (cached) | `id`, `name` |
| Refresh READ | `users`, `pm_tasks`, … | Loaded on refresh but **unused** by analytics UI | — |

**No WRITE.**

## Table schema

Uses cached `work_orders` and `assets` rows (see sections B/C). Analytics aggregates client-side: status counts, average duration from `createdAt` / `completedAt`.

## Storage

None.

## RLS / permissions (requestor)

Same as [03-my-requests.md](03-my-requests.md). Paginated load relies on RLS; client filters `requestorId`.

## Gap

Analytics does **not** call `loadRequestorWorkOrders`. It uses the first **30 work orders globally** by `createdAt`, then filters client-side. Older requestor WOs may be excluded from stats.

## Failure modes & troubleshooting

| Symptom | Cause |
|---------|-------|
| Stats seem low | Pagination + client filter |
| Stale numbers | Cache not refreshed |

## Verification SQL

```sql
SELECT status, count(*) FROM work_orders
WHERE "requestorId" = '<requestor-user-id>'
GROUP BY status;
```
