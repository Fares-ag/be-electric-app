# H. Notifications (In-App List)

## User-facing purpose

Requestor views in-app notification list and unread badge from overflow menu.

## Screens & entry points

| Component | Path |
|-----------|------|
| List | `lib/widgets/notification_list_screen.dart` |
| Badge | `lib/widgets/notification_badge.dart` |
| Service | `lib/services/notification_service.dart` |
| Init | `lib/bootstrap/cmms_bootstrap.dart` |

## Client stack

```
NotificationListScreen / NotificationBadge
  → NotificationService (singleton)
    → SharedPreferences key 'notifications' (JSON array)
    → Stream: notificationsStream
```

**Does not use** `UnifiedDataProvider` or Supabase for requestor UI.

## Database operations

| Operation | Target | Method |
|-----------|--------|--------|
| READ list | SharedPreferences | `notifications` key |
| WRITE mark read | SharedPreferences | update JSON |
| WRITE create | SharedPreferences | `createNotification` (called from other services) |

### Supabase `notifications` table (exists but unused here)

Live table columns: `id`, `title`, `message`, `type`, `priority`, `channel`, `userId`, `relatedId`, `relatedType`, `createdAt`, `isRead`, `readAt`, `data`, …

`SupabaseDatabaseService` has INSERT/SELECT for `notifications` (~line 2157) used by `EnhancedNotificationService` / admin — **not** wired to requestor list screen.

Live RLS includes `Users can read own notifications` / `notifications_select_own` (`userId`-scoped).

## Storage

Device-local only for requestor path.

## RLS / permissions (requestor)

N/A for current implementation (local prefs).

## Gap

| Issue | Detail |
|-------|--------|
| No server sync | Notifications don't follow user across devices |
| Table unused | `public.notifications` ready but not integrated |
| Push | OneSignal removed; no server push to requestor list |

## Failure modes & troubleshooting

| Symptom | Cause |
|---------|-------|
| Empty after reinstall | Local-only storage cleared |
| Badge wrong | Filter `userId` on stream |

## Verification SQL

```sql
-- Server notifications (not used by requestor UI today)
SELECT id, title, "userId", "isRead", "createdAt"
FROM notifications
ORDER BY "createdAt" DESC LIMIT 10;
```
