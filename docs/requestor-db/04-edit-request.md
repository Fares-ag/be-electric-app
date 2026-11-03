# D. Edit Maintenance Request

## User-facing purpose

Requestor edits an open or assigned work order (description, priority, category, photos) before work starts.

## Screens & entry points

| Screen | Path |
|--------|------|
| Edit | `lib/screens/requestor/edit_request_screen.dart` |
| Opened from | `lib/screens/work_orders/work_order_detail_screen.dart` |

## Client stack

```
EditRequestScreen._save
  → CmmsRepositories.workOrders.uploadFile (new photos)
  → UnifiedDataProvider.updateWorkOrder
    → WorkOrderProvider.updateWorkOrder
      → UnifiedDataService.updateWorkOrder
        → SupabaseDatabaseService.updateWorkOrder
          → work_orders UPDATE .eq('id')
```

Photo policy: `lib/utils/edit_photo_upload_decision.dart`.

## Database operations

| Operation | Target | Method | Key fields |
|-----------|--------|--------|------------|
| Upload new photos | Storage `files` | `uploadBinary` | `work_orders/request_photos/request_{workOrderId}_{timestamp}_{i}.jpg` |
| Update WO | `work_orders` | **Direct UPDATE** | `problemDescription`, `priority`, `category`, `photoPath`, `metadata.photoPaths`, `updatedAt` |

**Unlike create, edit does not use `upsert_work_order` RPC.**

## Table schema

Writable columns (client-enforced): `problemDescription`, `priority`, `category`, `photoPath`, `metadata` (photo paths). Status, `requestorId`, `assetId` are not changed from this screen.

Editable only when `status IN ('open', 'assigned')` (UI gate).

## Storage

| Path | Purpose |
|------|---------|
| `files/work_orders/request_photos/request_{workOrderId}_{timestamp}_{i}.jpg` | New attachments |

## RLS / permissions (requestor)

Live policy **Requestors can update own work orders**:

```sql
"requestorId" = auth.uid()::text
```

Direct UPDATE — RLS must allow row update. No SECURITY DEFINER wrapper.

## Admin/back-office notes

Technicians/admins have separate UPDATE policies when assigned or via admin role.

## Failure modes & troubleshooting

| Symptom | Cause |
|---------|-------|
| Save blocked in UI | Status not open/assigned |
| RLS error on save | `requestorId` mismatch |
| Photos not persisted | `metadata.photoPaths` merge failed |

## Verification SQL

```sql
SELECT id, status, "problemDescription", "metadata"->'photoPaths' AS photo_paths, "updatedAt"
FROM work_orders
WHERE "requestorId" = '<requestor-user-id>' AND status IN ('open', 'assigned')
ORDER BY "updatedAt" DESC LIMIT 5;
```
