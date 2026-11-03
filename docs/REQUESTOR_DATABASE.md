# Requestor App — Database Documentation

Maps every **requestor-facing** feature in `apps/requestor_cmms` to Supabase tables, RPCs, storage, and RLS.

| Item | Value |
|------|--------|
| App | `apps/requestor_cmms` |
| Shared package | `packages/cmms_core` |
| Supabase project | `sdhqjyjeczrbnvukrmny` |
| ID convention | `public.users.id`, `companies.id`, `work_orders.requestorId` are **text** (must equal `auth.uid()::text`) |
| Storage bucket | `files` |
| Last verified | Live schema via `./scripts/db.sh` (June 2026) |

## Architecture pattern

```
Screen → Provider → Service → Repository → SupabaseDatabaseService / SupabaseStorageService / SupabaseAuthService
```

Auth uses `AuthProvider` → `CmmsRepositories.users` directly (no `UnifiedDataProvider`).

Work orders and assets use `UnifiedDataProvider` → `WorkOrderProvider` → `UnifiedDataService` → `CmmsRepositories`.

Support requests use `SupportRequestProvider` → `SupportRequestService` → `SupabaseSupportRequestRepository`.

## Feature index

| Section | Feature | Doc | Primary tables |
|---------|---------|-----|----------------|
| A | Authentication & session | [01-authentication.md](requestor-db/01-authentication.md) | `auth.users`, `public.users` (RPC) |
| B | Create maintenance request | [02-create-maintenance-request.md](requestor-db/02-create-maintenance-request.md) | `work_orders`, `assets`, `companies`, Storage |
| C | My Requests / status / history | [03-my-requests.md](requestor-db/03-my-requests.md) | `work_orders` (+ Realtime) |
| D | Edit maintenance request | [04-edit-request.md](requestor-db/04-edit-request.md) | `work_orders`, Storage |
| E | Work order detail (cancel / reopen) | [05-work-order-detail.md](requestor-db/05-work-order-detail.md) | `work_orders`, `companies` |
| F | Be Electric Support | [06-be-electric-support.md](requestor-db/06-be-electric-support.md) | `support_requests`, Storage |
| G | Analytics | [07-analytics.md](requestor-db/07-analytics.md) | `work_orders`, `assets` (cache) |
| H | Notifications (in-app list) | [08-notifications.md](requestor-db/08-notifications.md) | **Local only** (gap) |
| I | Notification settings | [09-notification-settings.md](requestor-db/09-notification-settings.md) | **Local only** (gap) |
| J | Profile | [10-profile.md](requestor-db/10-profile.md) | `companies` (RPC at login) |
| K | Overflow menu | [11-overflow-menu.md](requestor-db/11-overflow-menu.md) | Navigation map |
| L | PPM / PM tasks | [12-ppm-preventive-maintenance.md](requestor-db/12-ppm-preventive-maintenance.md) | `pm_tasks` (no requestor RLS today) |

## Live tables used by requestor

Verified in `public` schema:

| Table | Requestor READ | Requestor WRITE |
|-------|----------------|-----------------|
| `users` | Via SECURITY DEFINER RPCs at login | Auto-create via `insert_user` RPC only |
| `companies` | SELECT (company name on profile / asset load) | — |
| `assets` | SELECT by `companyId` | — |
| `work_orders` | SELECT own rows; Realtime stream | INSERT via RPC; UPDATE (edit/cancel/reopen) |
| `support_requests` | SELECT own rows | INSERT (+ Storage uploads) |
| `pm_tasks` | **None** (no requestor RLS) | — |
| `notifications` | **Not used** by requestor UI today | — |

Related but not written by requestor app: `support_request_messages` (admin messaging; FK to `support_requests` was dropped during Flutter schema migration).

## RPCs used by requestor

| RPC | Purpose | SECURITY DEFINER |
|-----|---------|------------------|
| `get_user_by_email(p_email)` | Login / session profile | Yes |
| `get_user_by_id(p_id)` | Debug session restore | Yes |
| `insert_user(p_row)` | Auto-create user on first login | Yes |
| `upsert_work_order(p_row)` | Create maintenance request | Yes |

Direct table access (authenticated JWT, RLS applies): `work_orders` SELECT/UPDATE, `assets` SELECT, `companies` SELECT, `support_requests` INSERT/SELECT, Storage `files`.

## RLS summary (live policies)

| Table | Requestor SELECT | Requestor INSERT | Requestor UPDATE |
|-------|------------------|------------------|------------------|
| `work_orders` | `"requestorId" = auth.uid()::text` | `Authenticated can create work orders` | `"requestorId" = auth.uid()::text` |
| `assets` | `Authenticated can read assets` | — | — |
| `companies` | `Authenticated can read companies` | — | — |
| `support_requests` | `"createdBy" = auth.uid()::text` | same check on INSERT | — (admin only) |
| `users` | Own row + broad read policies | — | — |

Admin/manager policies use `get_my_role() IN ('admin','manager')` for full access.

## Storage paths (bucket `files`)

| Feature | Path pattern |
|---------|--------------|
| Maintenance request photos (review submit) | `work_orders/request_photos/request_{timestamp}_{n}.jpg` |
| Maintenance request photos (provider fallback) | `work_orders/photos/work_order_{workOrderId}_{timestamp}.jpg` |
| Edit request photos | `work_orders/request_photos/request_{workOrderId}_{timestamp}_{i}.jpg` |
| Support attachments | `support_requests/{supportRequestId}/{fileName}` |

Public URLs via `getPublicUrl` after upload.

## Known gaps (code vs backend)

| Gap | Impact | Mitigation |
|-----|--------|------------|
| Requestor notifications use **SharedPreferences**, not `notifications` table | No cross-device notification history | Future: wire `NotificationListScreen` to Supabase `notifications` |
| Notification settings prefs are **not read** by `NotificationService` | Settings have no effect | Wire service or remove screen from nav |
| Analytics uses **paginated global WO cache** (30 rows), not `getWorkOrdersByRequestor` | May miss older requestor WOs in stats | Call `loadRequestorWorkOrders` or increase page size |
| `support_request_messages` orphaned after schema migration | Admin threaded replies not linked | Re-add FK if React admin uses messages |
| Requestor sign-off on detail screen | Not implemented; signatures are technician-flow | Document for App Review |
| `users.id` must equal `auth.uid()::text` | RLS failures if admin creates user with wrong id | Sync ids in React admin user creation |

## Verification

Run the full requestor backend checklist:

```bash
./scripts/db.sh run scripts/sql/verify_requestor_backend.sql
./scripts/db.sh verify-support
./scripts/db.sh run scripts/sql/app_review_checklist.sql
```

## Related docs

- [SUPPORT_REQUESTS_BACKEND.md](SUPPORT_REQUESTS_BACKEND.md) — support migration SQL
- [FOR_REACT_FLUTTER_USER_FLOW.md](FOR_REACT_FLUTTER_USER_FLOW.md) — cross-app user flows
- [FOR_REACT_WHY_REQUESTOR_WOS_MISSING.md](FOR_REACT_WHY_REQUESTOR_WOS_MISSING.md) — admin visibility
- [FOR_REACT_WORK_ORDER_REOPEN.md](FOR_REACT_WORK_ORDER_REOPEN.md) — reopen metadata
- [DIRECT_DB_CLI.md](DIRECT_DB_CLI.md) — `./scripts/db.sh` usage
