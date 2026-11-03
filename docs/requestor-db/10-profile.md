# J. Profile

## User-facing purpose

Read-only account summary: name, email, role, company, status, legal links, account deletion info.

## Screens & entry points

| Screen | Path |
|--------|------|
| Profile | `lib/screens/profile/user_profile_screen.dart` |

Entry: overflow menu → Profile.

## Client stack

```
UserProfileScreen
  → AuthProvider.currentUser (in-memory, loaded at login)
  → CmmsRepositories.users.getCompanyById(companyId)
    → SupabaseDatabaseService.getCompanyById
      → companies SELECT .eq('id').maybeSingle()
```

Legal links: `lib/utils/legal_links.dart` (external URLs, no DB).

## Database operations

| Operation | Target | Method | Key fields |
|-----------|--------|--------|------------|
| READ user fields | — | From `AuthProvider` (populated via RPC at login) | `name`, `email`, `role`, `companyId`, … |
| READ company name | `companies` | SELECT | `id`, `name` |
| WRITE | — | **None** | Profile is read-only |

## Table schema

### `companies` (live)

| Column | Type |
|--------|------|
| `id` | text PK |
| `name` | text |
| `contactEmail`, `contactPhone`, `address` | text |
| `isActive` | boolean |
| `createdAt`, `updatedAt`, `metadata` | |

## Storage

None.

## RLS / permissions (requestor)

Live: **Authenticated can read companies** (SELECT).

User identity from SECURITY DEFINER RPCs at login (see [01-authentication.md](01-authentication.md)).

## Admin/back-office notes

Profile edits happen in React admin (`update_user` RPC), not in requestor app.

Account deletion: mailto / support URL only — no automated DB deletion from app.

## Failure modes & troubleshooting

| Symptom | Cause |
|---------|-------|
| Company name missing | Invalid `companyId` or company row deleted |
| Stale role | Re-login to refresh from RPC |

## Verification SQL

```sql
SELECT u.email, u.name, u.role, u."companyId", c.name AS company_name
FROM users u
LEFT JOIN companies c ON c.id = u."companyId"
WHERE u.role = 'requestor'
LIMIT 10;
```
