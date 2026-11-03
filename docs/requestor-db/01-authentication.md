# A. Authentication & Session Restore

## User-facing purpose

Requestors sign in with email/password, restore session on cold start, and reset password via email link.

## Screens & entry points

| Screen | Path |
|--------|------|
| Login | `packages/cmms_core/lib/screens/auth/login_screen.dart` |
| Splash / auth wrapper | `packages/cmms_core/lib/screens/requestor/requestor_splash_screen.dart`, `bootstrap/cmms_bootstrap.dart` |

## Client stack

```
LoginScreen
  → AuthProvider.login / checkAuthStatus
    → SupabaseAuthService (Supabase Auth API)
    → CmmsRepositories.users (SupabaseUserRepository)
      → SupabaseDatabaseService (RPCs)
```

| Layer | File |
|-------|------|
| Provider | `lib/providers/auth_provider.dart` |
| Auth service | `lib/services/supabase_auth_service.dart` |
| Repository | `lib/repositories/supabase/supabase_user_repository.dart` |
| DB service | `lib/services/supabase_database_service.dart` |

## Database operations

| Operation | Target | Method | Key fields |
|-----------|--------|--------|------------|
| Sign in | `auth.users` | Supabase Auth `signInWithPassword` | `email`, `password` |
| Load profile | `public.users` | RPC `get_user_by_email` | `p_email` |
| Auto-create profile | `public.users` | RPC `insert_user` | `p_row.id` = Auth UUID, `email`, `role`, `name`, `companyId`, … |
| Session restore | `public.users` | RPC `get_user_by_email` or `get_user_by_id` | `p_id` / email |
| Forgot password | `auth.users` | Auth `resetPasswordForEmail` | `email` |
| Logout | Session | Auth `signOut` + clear `SharedPreferences` `current_user_id` | — |

## Table schema

### `public.users` (live)

| Column | Type | Notes |
|--------|------|-------|
| `id` | text PK | Must match `auth.uid()::text` for RLS on work orders / support |
| `email` | text | Lowercase |
| `name` | text | |
| `role` | text | Requestor app requires `requestor` |
| `companyId` | text | FK → `companies.id`; required for maintenance submit |
| `department`, `workEmail`, `isActive`, `createdAt`, `lastLoginAt`, `updatedAt` | | |

Flutter does **not** SELECT `users` directly; it uses SECURITY DEFINER RPCs.

## Storage

None.

## RLS / permissions (requestor)

- User RPCs (`get_user_by_email`, `insert_user`, `get_user_by_id`) are **SECURITY DEFINER** — bypass table RLS.
- RPCs require an active Supabase Auth session (`_currentUserId != null` in `SupabaseDatabaseService`).
- Release builds: no local session restore without Supabase Auth (comment: “RLS-safe”).
- Debug builds: may restore from `SharedPreferences` `current_user_id` → `get_user_by_id`.

Live `users` table has many SELECT policies; requestor login path does not depend on them.

## Admin/back-office notes

- React admin must create `public.users` row with `id` = Auth user UUID and `role = 'requestor'`.
- If `AppConfig.autoCreateUsersOnLogin` is true, Flutter can create the row via `insert_user` on first login.

## Failure modes & troubleshooting

| Symptom | Cause |
|---------|-------|
| Login succeeds but immediately logged out | No `public.users` row for email |
| Work orders empty after login | `users.id` ≠ `auth.uid()::text` |
| “User must be created by admin” | `autoCreateUsersOnLogin` false and no DB row |

## Verification SQL

```sql
-- Requestor users for App Review
SELECT id, email, name, role, "companyId", "isActive"
FROM users WHERE role = 'requestor' ORDER BY email LIMIT 20;

-- Id alignment (should return rows where ids match auth)
SELECT u.id, u.email, u.role
FROM users u
WHERE u.role = 'requestor'
LIMIT 10;
```
