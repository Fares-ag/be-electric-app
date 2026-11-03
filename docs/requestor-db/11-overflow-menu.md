# K. Overflow Menu Navigation

## User-facing purpose

Consistent “more” menu across requestor screens for navigation, profile, notifications, analytics, support, and logout.

## Screens & entry points

| Component | Path |
|-----------|------|
| Menu | `lib/widgets/requestor_more_menu.dart` |

Used from `RequestorMainScreen`, support screens, analytics, status, etc.

## Navigation map

| Menu item | Destination | Database impact |
|-----------|-------------|-----------------|
| **Primary** (caller-defined) | e.g. Home → `RequestorMainScreen`; “View My Requests” → `RequestorStatusScreen` | See linked feature doc |
| **Profile** | `UserProfileScreen` | [10-profile.md](10-profile.md) |
| **Notifications** | `NotificationListScreen` | [08-notifications.md](08-notifications.md) (local) |
| **Analytics** | `RequestorAnalyticsScreen` | [07-analytics.md](07-analytics.md) |
| **Be Electric Support** | `RequestorSupportScreen` → Know How / Commissioning / My Support Requests | [06-be-electric-support.md](06-be-electric-support.md) |
| **Logout** | `AuthProvider.logout()` → `LoginScreen` | Auth sign-out; clears `current_user_id` prefs |

### Not in menu

| Screen | Notes |
|--------|-------|
| `RequestorNotificationSettingsScreen` | Exists but no nav entry |
| `RequestorDashboardScreen` | Legacy/alternate dashboard (tabs) — not in overflow menu |

## Client stack

Navigation only — no direct database calls in `requestor_more_menu.dart`.

Logout chain: `AuthProvider.logout` → `SupabaseAuthService.signOut` → remove SharedPreferences `current_user_id`.

## Database operations

None in menu widget itself. See destination docs.

## Verification

Confirm menu routes match product spec; no SQL required.
