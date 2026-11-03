# F. Be Electric Support

## User-facing purpose

Requestors submit **Know How** and **Commissioning** support requests with attachments, then view history and staff replies.

## Screens & entry points

| Screen | Path |
|--------|------|
| Hub | `lib/screens/requestor/support/requestor_support_screen.dart` |
| Know How form | `lib/screens/requestor/support/know_how_support_screen.dart` |
| Commissioning form | `lib/screens/requestor/support/commissioning_support_screen.dart` |
| My Support Requests | `lib/screens/requestor/support/my_support_requests_screen.dart` |
| Detail | `lib/screens/requestor/support/support_request_detail_screen.dart` |

Home also links directly to Know How / Commissioning from `requestor_main_screen.dart`. Overflow menu → Be Electric Support hub.

## Client stack

```
Submit (Know How / Commissioning)
  → SupportRequestProvider.submit*
    → SupportRequestService
      → SupabaseSupportRequestRepository
        → SupabaseStorageService.uploadFile (attachments)
        → SupabaseDatabaseService.createSupportRequest (INSERT)

List
  → SupportRequestProvider.loadSupportRequests
    → getSupportRequestsForCurrentUser
      → SupabaseDatabaseService.getSupportRequestsForUser (SELECT)

Detail
  → In-memory SupportRequest from list
  → openSupportAttachmentUrl → launchLegalUrl (public HTTP)
```

| Layer | File |
|-------|------|
| Provider | `lib/providers/support_request_provider.dart` |
| Service | `lib/services/support_request_service.dart` |
| Repository | `lib/repositories/supabase/supabase_support_request_repository.dart` |
| Model | `lib/models/support_request.dart` |
| Backend doc | [SUPPORT_REQUESTS_BACKEND.md](../SUPPORT_REQUESTS_BACKEND.md) |
| Migration | `scripts/sql/migrate_support_requests.sql` |

## Database operations

| Operation | Target | Method | Key fields |
|-----------|--------|--------|------------|
| Upload attachment | Storage `files` | `uploadBinary` upsert | `support_requests/{id}/{fileName}` |
| Submit | `support_requests` | INSERT `.select()` | See schema below |
| List | `support_requests` | SELECT `.eq('createdBy', userId).order('createdAt', desc)` | `createdBy` |
| Detail | — | No extra fetch | Passed from list |

No RPCs for support requests.

### Row mapping by type

| Field | Know How | Commissioning |
|-------|----------|---------------|
| `type` | `knowHow` | `commissioning` |
| `topic`, `question` | required | — |
| `summary` | topic duplicate | required |
| `chargerModel` | optional | required |
| `chargerSerialNumber`, `address`, `country`, `scheduledDate`, `details` | — | required |
| `attachments` | URL array | URL array |
| `createdBy`, `companyId` | current user | current user |
| `status` | `submitted` | `submitted` |
| `staffReply` | read only (admin sets) | read only |

## Table schema (live verified)

| Column | Type |
|--------|------|
| `id` | uuid PK |
| `type`, `status` | text |
| `summary`, `topic`, `question`, `details` | text |
| `chargerModel`, `chargerSerialNumber`, `address`, `country` | text |
| `scheduledDate` | timestamptz |
| `attachments` | jsonb (default `[]`) |
| `createdBy` | text FK → `users.id` |
| `createdAt` | timestamptz |
| `companyId` | text FK → `companies.id` |
| `staffReply` | text |

**Note:** Legacy schema (`requesterId`, `subject`, `ticketNumber`) was replaced June 2026 via `migrate_support_requests.sql` (empty table). `support_request_messages` FK was dropped during migration.

## Storage

| Bucket | Path | RLS |
|--------|------|-----|
| `files` | `support_requests/{supportRequestId}/{fileName}` | Authenticated INSERT/UPDATE on prefix |

Reads: public URL in `attachments` array.

## RLS / permissions (requestor)

Live policies:

| Policy | Cmd | Expression |
|--------|-----|------------|
| Requestors insert own support requests | INSERT | `"createdBy" = auth.uid()::text` |
| Requestors read own support requests | SELECT | `"createdBy" = auth.uid()::text` |
| Admins manage support_requests | ALL | `get_my_role() IN ('admin','manager')` |

## Admin/back-office notes

Staff set `staffReply` and `status` via admin tools or SQL UPDATE under admin policy.

Orphan table `support_request_messages` may need FK restored for threaded admin replies.

## Failure modes & troubleshooting

| Symptom | Cause |
|---------|-------|
| Submit fails | Table/RLS/storage policy missing — run `./scripts/db.sh migrate-support` |
| List empty | Wrong `createdBy` on rows |
| Attachment won't open | Invalid public URL or bucket not public |

## Verification SQL

```sql
-- Full checklist
-- ./scripts/db.sh verify-support

SELECT id, type, status, "createdBy", "createdAt",
       CASE WHEN "staffReply" IS NULL THEN '—' ELSE 'set' END AS staff_reply
FROM support_requests
ORDER BY "createdAt" DESC LIMIT 10;
```
