# Repository Pattern Migration Summary

Migration introduces a Repository layer between UI/providers and Supabase persistence **without changing models, UI, or runtime behavior**. Supabase implementations are thin delegates to the existing `SupabaseDatabaseService` and `SupabaseStorageService` for backward compatibility.

## Architecture

```
Screens / Widgets
       ↓
Providers (Auth, Inventory, UnifiedData)
       ↓
UnifiedDataService (cache + orchestration)
       ↓
CmmsRepositories (registry)
       ↓
Repository interfaces → Supabase*Repository → Supabase*Service
```

Access repositories via `CmmsRepositories`:

```dart
CmmsRepositories.workOrders
CmmsRepositories.assets
CmmsRepositories.users
CmmsRepositories.inventory
CmmsRepositories.workflows
```

GetIt registration in `setupServiceLocator()` wires the same instances into `CmmsRepositories.configure()`.

---

## Files Created

| File | Purpose |
|------|---------|
| `packages/cmms_core/lib/repositories/work_order_repository.dart` | Work orders, PM tasks, file uploads |
| `packages/cmms_core/lib/repositories/asset_repository.dart` | Asset CRUD, company assets, QR lookup |
| `packages/cmms_core/lib/repositories/user_repository.dart` | Users + companies |
| `packages/cmms_core/lib/repositories/inventory_repository.dart` | Inventory CRUD |
| `packages/cmms_core/lib/repositories/workflow_repository.dart` | Workflow CRUD |
| `packages/cmms_core/lib/repositories/cmms_repositories.dart` | Singleton registry + `configure()` / `resetForTesting()` |
| `packages/cmms_core/lib/repositories/supabase/supabase_work_order_repository.dart` | Supabase delegate |
| `packages/cmms_core/lib/repositories/supabase/supabase_asset_repository.dart` | Supabase delegate |
| `packages/cmms_core/lib/repositories/supabase/supabase_user_repository.dart` | Supabase delegate |
| `packages/cmms_core/lib/repositories/supabase/supabase_inventory_repository.dart` | Supabase delegate |
| `packages/cmms_core/lib/repositories/supabase/supabase_workflow_repository.dart` | Supabase delegate |

---

## Files Modified

### Bootstrap & DI

- `packages/cmms_core/lib/bootstrap/cmms_bootstrap.dart` — DB init via `CmmsRepositories.workOrders.initialize()`
- `packages/cmms_core/lib/config/service_locator.dart` — registers all five repositories in GetIt

### Services

- `packages/cmms_core/lib/services/unified_data_service.dart` — all ~40 direct `SupabaseDatabaseService` calls replaced with repository calls

### Providers

- `packages/cmms_core/lib/providers/auth_provider.dart` — user lookup/CRUD via `CmmsRepositories.users`
- `packages/cmms_core/lib/providers/inventory_provider.dart` — inventory CRUD via `CmmsRepositories.inventory`
- `packages/cmms_core/lib/providers/unified_data_provider.dart` — work-order fetch, user fetch, photo upload via repositories

### Screens (DB calls removed)

- `screens/profile/user_profile_screen.dart`
- `screens/requestor/requestor_main_screen.dart`
- `screens/requestor/create_maintenance_request_screen.dart`
- `screens/admin/create_company_screen.dart`
- `screens/admin/company_management_screen.dart`
- `screens/admin/company_chargers_screen.dart`
- `screens/admin/create_user_screen.dart`
- `screens/admin/user_management_screen.dart`
- `screens/work_orders/work_order_detail_screen.dart`
- `screens/work_orders/work_order_list_screen.dart`
- `screens/settings/legacy_mode_screen.dart`

### Screens (storage calls removed)

- `screens/requestor/review_maintenance_request_screen.dart`
- `screens/requestor/edit_request_screen.dart`
- `screens/work_orders/work_order_completion_screen.dart`
- `screens/work_orders/mobile_create_work_request_screen.dart`
- `screens/pm_tasks/pm_task_completion_screen.dart`

### Widgets

- `widgets/qr_scanner_widget.dart`
- `widgets/mobile_qr_scanner_widget.dart`

---

## Responsibilities Moved

| From | To | Operations |
|------|----|------------|
| `UnifiedDataService` | `WorkOrderRepository`, `AssetRepository`, `UserRepository`, `InventoryRepository`, `WorkflowRepository` | All aggregate CRUD, queries, pagination, pause/resume |
| `AuthProvider` | `UserRepository` | `getUserByEmail`, `getUserById`, `createUser`, `getAllUsers` |
| `InventoryProvider` | `InventoryRepository` | Full inventory CRUD |
| `UnifiedDataProvider` | `WorkOrderRepository`, `UserRepository` | `getWorkOrder`, `getUserById`, photo uploads |
| Screens/widgets | Respective repositories | Company/asset/user lookups, QR scan, storage uploads |
| `cmms_bootstrap.dart` | `WorkOrderRepository` | Database initialization |

### Aggregate boundaries (intentional grouping)

- **WorkOrderRepository** — work orders, PM tasks, and storage uploads (photos, signatures, completion files)
- **UserRepository** — users and companies (admin B2B tenant model)
- **AssetRepository** — assets including company-scoped and QR lookups
- **InventoryRepository** — inventory items
- **WorkflowRepository** — approval workflows

---

## Backward Compatibility

- `SupabaseDatabaseService` and `SupabaseStorageService` remain unchanged and are still used internally by Supabase repository implementations.
- `CmmsRepositories` lazy-instantiates default Supabase repos if GetIt has not run (e.g. tests).
- `RepositoryLocator` typedef aliases `CmmsRepositories` for gradual migration.
- No model or API surface changes; existing provider methods unchanged.

---

## Verification

- `flutter test` in `packages/cmms_core` — **144 passed** (4 skipped integration tests)
- Providers, screens, and widgets no longer import or call `SupabaseDatabaseService` / `SupabaseStorageService` directly

---

## Remaining Technical Debt

### Services still calling `SupabaseDatabaseService` directly

These domains were out of scope (no repository interfaces yet):

| Service | Notes |
|---------|-------|
| `parts_request_service.dart` | Parts requests + inventory cross-calls |
| `purchase_order_service.dart` | PO + user/inventory lookups |
| `realtime_supabase_service.dart` | Realtime streams (wraps DB service) |
| `enhanced_inventory_service.dart` | Extended inventory logic |
| `enhanced_notification_service.dart` | Notification persistence |
| `audit_logging_service.dart` | Audit trail writes |
| `escalation_service.dart` | Escalation rules |
| `orphan_cleanup_service.dart` | Maintenance utilities |

### Utility scripts (admin/diagnostic, not app runtime)

- `utils/user_id_diagnostic.dart`
- `utils/fix_unknown_admin.dart`
- `utils/cleanup_unknown_users.dart`
- `utils/cleanup_all_duplicates.dart`

### Structural debt (unchanged by this refactor)

- `UnifiedDataProvider` remains a large god class (~2k LOC) with dual-cache complexity
- `UnifiedDataService` still owns in-memory caches alongside repository persistence
- Realtime subscriptions still bypass repositories via `RealtimeSupabaseService`
- PM tasks live on `WorkOrderRepository` rather than a dedicated aggregate
- Companies live on `UserRepository` rather than a dedicated aggregate
- No repository interfaces yet for parts requests, notifications, audit logs, vendors, or purchase orders
- Screens call `CmmsRepositories` directly in some admin/requestor flows; a future phase could route exclusively through provider methods

### Recommended next steps

1. Add `PartsRequestRepository`, `NotificationRepository`, migrate remaining services
2. Inject repositories into `UnifiedDataService` constructor (remove static registry for testability)
3. Collapse dual-cache in `UnifiedDataProvider` / `UnifiedDataService`
4. Route realtime streams through repository interfaces
5. Add repository unit tests with mocked Supabase clients
