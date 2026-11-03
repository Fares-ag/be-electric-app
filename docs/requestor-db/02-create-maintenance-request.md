# B. Home / Create Maintenance Request

## User-facing purpose

Requestor selects Siemens or Kostad charger (or scans QR), describes the problem, attaches photos, and submits a maintenance work order.

## Screens & entry points

| Screen | Path |
|--------|------|
| Home | `lib/screens/requestor/requestor_main_screen.dart` |
| Create form | `lib/screens/requestor/create_maintenance_request_screen.dart` |
| Review & submit | `lib/screens/requestor/review_maintenance_request_screen.dart` |
| Success | `lib/screens/requestor/submission_success_screen.dart` |

Asset helpers: `lib/utils/charger_asset_filter.dart`, `lib/utils/requestor_work_order_asset.dart`, `lib/utils/requestor_company_policy.dart`, `lib/utils/requestor_submit_readiness.dart`.

## Client stack

```
ReviewMaintenanceRequestScreen._submitRequest
  → CmmsRepositories.workOrders.uploadFile (photos)
  → UnifiedDataProvider.createWorkOrder
    → WorkOrderProvider.createWorkOrder
      → UnifiedDataService.createWorkOrder
        → SupabaseWorkOrderRepository.createWorkOrder
          → SupabaseDatabaseService.createWorkOrder (RPC upsert_work_order)
          → optional work_orders UPDATE (metadata.photoPaths)

CreateMaintenanceRequestScreen (asset load)
  → CmmsRepositories.users.getCompanyById
  → CmmsRepositories.assets.getAssetsByCompanyId
```

| Layer | File |
|-------|------|
| Provider | `lib/providers/unified_data_provider.dart`, `lib/providers/work_order_provider.dart` |
| Service | `lib/services/unified_data_service.dart` |
| Repository | `lib/repositories/supabase/supabase_work_order_repository.dart`, `supabase_asset_repository.dart`, `supabase_user_repository.dart` |
| Storage | `lib/services/supabase_storage_service.dart` |

## Database operations

| Operation | Target | Method | Key fields |
|-----------|--------|--------|------------|
| Load company | `companies` | SELECT `.eq('id', companyId)` | `id`, `name` |
| Load chargers | `assets` | SELECT `.eq('companyId', companyId)` | `manufacturer`, `name`, `qrCode`, `model` |
| Upload photos | Storage `files` | `uploadBinary` | See Storage below |
| Create WO | `work_orders` | RPC **`upsert_work_order`** | `p_row`: `id`, `requestorId`, `requestorName`, `companyId`, `assetId`, `problemDescription`, `status`, `priority`, `category`, `notes`, `customerName/Phone/Email`, `photoPath`, `metadata` |
| Photo metadata patch | `work_orders` | UPDATE `.eq('id')` | `metadata.photoPaths`, `photoPath` |

**Create uses RPC (SECURITY DEFINER).** Follow-up metadata UPDATE uses direct table access with RLS.

Non-UUID `assetId` / `companyId` values are moved to `metadata.appAssetId` / `metadata.appCompanyId` in `SupabaseDatabaseService`.

## Table schema (required columns)

### `work_orders` (submit-relevant, live)

| Column | Type | Set on create |
|--------|------|---------------|
| `id` | text | Client UUID |
| `ticketNumber` | text | Generated |
| `requestorId` | text | `currentUser.id` |
| `requestorName` | text | `currentUser.name` |
| `companyId` | text | User's company |
| `assetId` | text | Selected charger (optional) |
| `problemDescription` | text | Required |
| `status` | text | `open` |
| `priority`, `category`, `notes` | text | Form |
| `photoPath` | text | First photo URL |
| `metadata` | jsonb | `photoPaths`, reopen fields, app FK fallbacks |
| `customerName`, `customerPhone`, `customerEmail` | text | Optional contact |
| `createdAt`, `updatedAt` | timestamptz | |

### `assets` (read for selection)

Key columns: `id`, `name`, `manufacturer`, `model`, `qrCode`, `companyId`, `status`.

### `companies` (read)

Key columns: `id`, `name`, `isActive`.

## Storage

| Step | Bucket | Path |
|------|--------|------|
| Review screen upload | `files` | `work_orders/request_photos/request_{timestamp}_{n}.jpg` |
| Provider fallback (local paths) | `files` | `work_orders/photos/work_order_{workOrderId}_{timestamp}.jpg` |

Reads: public URL stored on row / in `metadata.photoPaths`.

## RLS / permissions (requestor)

| Op | Policy (live) |
|----|-----------------|
| INSERT (via RPC) | RPC is SECURITY DEFINER — insert succeeds independent of direct INSERT policy |
| UPDATE metadata | `Requestors can update own work orders`: `"requestorId" = auth.uid()::text` |
| SELECT assets | `Authenticated can read assets` |
| SELECT companies | `Authenticated can read companies` |

Client gates: user must have `companyId`; Siemens/Kostad assets must exist for company (see `app_review_checklist.sql`).

## Admin/back-office notes

- Rows appear in React admin `work_orders` immediately if admin RLS allows (`get_my_role()` admin/manager).
- See [FOR_REACT_WHY_REQUESTOR_WOS_MISSING.md](../FOR_REACT_WHY_REQUESTOR_WOS_MISSING.md).

## Failure modes & troubleshooting

| Symptom | Cause |
|---------|-------|
| No chargers on home | Company has no Siemens/Kostad assets |
| Submit fails pre-upload | Missing `companyId` on user |
| RPC error | `upsert_work_order` not deployed or invalid row |
| Photos missing on row | Storage upload failed or metadata UPDATE blocked |

## Verification SQL

```sql
-- Recent requestor work orders
SELECT id, "ticketNumber", status, "requestorId", "companyId", "assetId", "createdAt"
FROM work_orders
ORDER BY "createdAt" DESC LIMIT 10;

-- Company charger counts (App Review)
SELECT c.name,
  count(a.id) FILTER (WHERE a.manufacturer ILIKE '%siemens%') AS siemens,
  count(a.id) FILTER (WHERE a.manufacturer ILIKE '%kostad%') AS kostad
FROM companies c
LEFT JOIN assets a ON a."companyId" = c.id
GROUP BY c.id, c.name;
```
