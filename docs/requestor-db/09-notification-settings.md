# I. Notification Settings

## User-facing purpose

Requestor configures which work-order events trigger notifications (assigned, started, completed, etc.).

## Screens & entry points

| Screen | Path |
|--------|------|
| Settings | `lib/screens/requestor/requestor_notification_settings_screen.dart` |

**Not linked** from overflow menu or home (orphaned screen in current nav).

## Client stack

```
RequestorNotificationSettingsScreen
  → SharedPreferences directly (no Provider)
```

## Database operations

| Operation | Target | Method |
|-----------|--------|--------|
| READ | SharedPreferences | 10 keys on load |
| WRITE | SharedPreferences | on toggle save |

### Preference keys (all local)

`notify_on_assigned`, `notify_on_started`, `notify_on_completed`, `notify_on_cancelled`, `notify_on_updated`, `notify_on_overdue`, `enable_push_notifications`, `enable_email_notifications`, `enable_sms_notifications`, `notification_frequency`.

**No Supabase READ/WRITE.**

## Table schema

N/A.

## Storage

SharedPreferences only.

## RLS / permissions

N/A.

## Gap

**No consumer:** `NotificationService` does not read these prefs. Settings persist but have **no effect** on notification delivery. Push/email/SMS toggles marked “coming soon” in UI.

## Verification

No SQL. Manual: inspect device SharedPreferences or add integration test.
