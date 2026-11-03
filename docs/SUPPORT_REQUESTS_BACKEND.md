# Be Electric Support Requests — Backend Setup

The Requestor app submits **Know How** and **Commissioning** support requests through the client stack:

`SupportRequestProvider` → `SupportRequestService` → `SupportRequestRepository` → Supabase.

This document describes the Supabase resources the mobile client expects.

## Quick apply (recommended)

1. Configure DB credentials: `cp scripts/db.env.example scripts/db.env` and set `DATABASE_URL`.
2. Run the migration:

   ```bash
   ./scripts/db.sh migrate-support
   ```

3. Verify:

   ```bash
   ./scripts/db.sh verify-support
   ```

Alternatively, paste `scripts/sql/migrate_support_requests.sql` into the **Supabase Dashboard → SQL Editor**, or apply via Supabase CLI:

```bash
supabase db push   # uses supabase/migrations/20260625120000_support_requests.sql
```

## What the migration creates

| Resource | Purpose |
|----------|---------|
| Table `public.support_requests` | Stores Know How + Commissioning requests |
| RLS INSERT/SELECT for requestors | Submit + **My Support Requests** list/detail |
| RLS SELECT/UPDATE for admin/manager | Staff can read all rows and set `staffReply` / `status` (requires `get_my_role()`) |
| Storage INSERT/UPDATE on `files/support_requests/` | Attachment uploads (client uses `upsert: true`) |

## Storage bucket

| Setting | Value |
|--------|--------|
| Bucket name | `files` (existing CMMS bucket) |
| Upload path | `support_requests/{supportRequestId}/{fileName}` |
| Public URLs | Returned via `getPublicUrl` after upload (same as work-order photos) |

The migration adds storage policies for authenticated upload/update under the `support_requests/` prefix. Reads use public URLs on the existing `files` bucket.

## Table: `support_requests`

CamelCase columns match existing CMMS conventions. Full DDL is in `scripts/sql/migrate_support_requests.sql`.

Key columns:

| Column | Notes |
|--------|--------|
| `type` | `knowHow` or `commissioning` |
| `status` | `submitted`, `open`, `inProgress`, `resolved`, `closed` |
| `createdBy` | Must equal `auth.uid()` (same as `public.users.id`) |
| `attachments` | JSON array of public Storage URLs |
| `staffReply` | Optional; shown in app detail when set by admin |

### Row mapping by request type

| Field | Know How | Commissioning |
|-------|----------|---------------|
| `type` | `knowHow` | `commissioning` |
| `topic` | required | — |
| `question` | required | — |
| `summary` | topic (duplicate for search) | required |
| `chargerModel` | optional | required |
| `chargerSerialNumber` | — | required |
| `address` | — | required |
| `country` | — | required |
| `scheduledDate` | — | required |
| `details` | — | required |
| `attachments` | uploaded file URLs | uploaded file URLs |
| `createdBy` | auth user id (`public.users.id`, same as `auth.uid()::text`) |
| `companyId` | requestor company | requestor company |
| `status` | `submitted` | `submitted` |
| `staffReply` | optional staff response | optional staff response |

## RLS summary

**Requestors** (required for the mobile app):

- `INSERT` where `"createdBy" = auth.uid()::text`
- `SELECT` where `"createdBy" = auth.uid()::text`

**Admins / managers** (back-office; requires `public.get_my_role()` from CMMS migrations):

- `ALL` on `support_requests` via policy **Admins manage support_requests** (read, update `staffReply` / `status`, etc.)

Example staff reply via SQL Editor:

```sql
UPDATE public.support_requests
SET
  status = 'resolved',
  "staffReply" = 'Thanks — we have scheduled a call for next Tuesday.'
WHERE id = 'YOUR-REQUEST-UUID';
```

## Client behaviour

1. Generates a UUID for the request before uploading attachments.
2. Uploads each attachment to `files/support_requests/{id}/`.
3. Inserts the row into `support_requests` with attachment URLs in the `attachments` JSON array.
4. **My Support Requests** loads rows with `.eq('createdBy', userId).order('createdAt', descending)`.

If the table or bucket policies are missing, the user sees a friendly error SnackBar and no partial row is left without attachments (upload failures abort before insert).

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| Submit fails with RLS error | `"createdBy"` ≠ `auth.uid()::text` — ensure `public.users.id` matches Auth user id |
| List is always empty | SELECT policy missing, or wrong `createdBy` on inserted rows |
| Attachment upload fails | Storage policy missing for `files/support_requests/` |
| Admin cannot update `staffReply` | `get_my_role()` missing or user not admin/manager in `public.users` |

Run `./scripts/db.sh verify-support` for a checklist.

## Related code

| Layer | Location |
|-------|----------|
| Model | `packages/cmms_core/lib/models/support_request.dart` |
| Repository | `packages/cmms_core/lib/repositories/support_request_repository.dart` |
| Supabase repo | `packages/cmms_core/lib/repositories/supabase/supabase_support_request_repository.dart` |
| Service | `packages/cmms_core/lib/services/support_request_service.dart` |
| Provider | `packages/cmms_core/lib/providers/support_request_provider.dart` |
| List screen | `packages/cmms_core/lib/screens/requestor/support/my_support_requests_screen.dart` |
| Detail screen | `packages/cmms_core/lib/screens/requestor/support/support_request_detail_screen.dart` |
| DB insert | `SupabaseDatabaseService.createSupportRequest` |
| DB list | `SupabaseDatabaseService.getSupportRequestsForUser` |
| Migration SQL | `scripts/sql/migrate_support_requests.sql` |
| Verify SQL | `scripts/sql/verify_support_requests.sql` |
