# E. Work Order Detail — Cancel / Reopen

## User-facing purpose

Requestor opens a work order detail, cancels open requests, reopens completed/closed ones, and navigates to edit. Sign-off is **not** on this screen (technician completion flow).

## Screens & entry points

| Screen | Path |
|--------|------|
| Detail | `lib/screens/work_orders/work_order_detail_screen.dart` |
| Reopen dialog | `lib/widgets/reopen_work_order_dialog.dart` |
| Edit | → [04-edit-request.md](04-edit-request.md) |

Activity timeline on detail uses `lib/services/activity_log_service.dart` (**SharedPreferences only**, not Supabase).

## Client stack

```
WorkOrderDetailScreen
  → CmmsRepositories.workOrders.getWorkOrder (hydrate)
  → UnifiedDataProvider.cancelWorkOrder / reopenWorkOrder
    → WorkOrderProvider → UnifiedDataService → updateWorkOrder
      → SupabaseDatabaseService.updateWorkOrder
  → CmmsRepositories.users.getCompanyById (company label)
```

## Database operations

| Operation | Target | Method | Key fields |
|-----------|--------|--------|------------|
| Hydrate | `work_orders` | SELECT `.eq('id').single()` | all columns + `metadata` |
| Cancel | `work_orders` | UPDATE | `status = cancelled`, `updatedAt` |
| Reopen | `work_orders` | UPDATE | `status = reopened`, `problemDescription`, clears assignee/timing fields, **`metadata`**: `reopenedAt`, `reopenedBy`, `reopenReason`, `reopenCount`, `previousStatus`, … |
| Company name | `companies` | SELECT | `id`, `name` |

### Reopen rules (client)

- Prior status: `completed`, `closed`, or `cancelled`
- `reopenCount < 3`
- `workOrder.requestorId == currentUserId`
- Fresh row fetched before update

See [FOR_REACT_WORK_ORDER_REOPEN.md](../FOR_REACT_WORK_ORDER_REOPEN.md).

### Sign-off gap (T-004 Option A)

Technician completion requires **technician signature only**. `requestorSignature` is not collected on the completion screen; requestor sign-off remains a future enhancement (requestor app or admin).

## Table schema

Reopen/cancel use `status`, `updatedAt`, `metadata` jsonb. Reopen fields may not exist as top-level columns — stored in `metadata` via `_mergeWorkOrderPhotoMetadataIntoRow` / reopen helpers in `supabase_database_service.dart`.

## Storage

Display only: problem/completion photo URLs from row and `metadata`.

## RLS / permissions (requestor)

Same as edit: **Requestors can update own work orders** where `"requestorId" = auth.uid()::text`.

## Admin/back-office notes

Reopen count and reason visible in `metadata` for admin portal parsing.

## Failure modes & troubleshooting

| Symptom | Cause |
|---------|-------|
| Reopen disabled | Max reopen count or wrong status |
| Cancel hidden | Status in progress / completed |
| Activity log empty on other device | Local-only activity log |

## Verification SQL

```sql
SELECT id, status, "metadata"->>'reopenCount' AS reopen_count,
       "metadata"->>'reopenedAt' AS reopened_at
FROM work_orders
WHERE "requestorId" = '<requestor-user-id>'
ORDER BY "updatedAt" DESC LIMIT 10;
```
