# Release Safety Report

Audit date: 2025-06-25  
Scope: `packages/cmms_core` (shared by requestor and technician apps)

## Summary

Production release builds (`flutter build --release` / App Store) now **hide and block** dev-only admin tooling by default. Destructive database utilities require an explicit second compile-time flag even in profile builds.

**Gate module:** `packages/cmms_core/lib/config/release_safety.dart`

| Flag | Default in release | Opt-in |
|------|-------------------|--------|
| `ReleaseSafety.showDevTools` | `false` | `--dart-define=ENABLE_DEV_TOOLS=true` |
| `ReleaseSafety.allowDestructiveAdminTools` | `false` | `--dart-define=ENABLE_DESTRUCTIVE_ADMIN_TOOLS=true` |
| `ReleaseSafety.allowDataSeeding` | same as `showDevTools` | same as `showDevTools` |

Debug builds (`flutter run`, `kDebugMode == true`) retain all tools for local development.

Production builds use `scripts/build_production.sh` with `defines.production.json` — **do not** add dev-tool flags to that file.

---

## Classification

### BLOCK — Gated (was reachable in production admin app)

These were exposed via **Admin → overflow menu** (mobile + desktop) or technician/asset UI and could mutate or wipe live Supabase data.

| Item | Location | Gate applied |
|------|----------|--------------|
| Complete database wipe | `utils/complete_database_wipe.dart` | Menu hidden + dialog/API guard |
| Nuclear option (kill all + block sample data) | `utils/kill_duplicates_now.dart` | Menu hidden + dialog/API guard |
| Database reset utility | `utils/database_reset_utility.dart` | Menu hidden + dialog/API guard |
| Remove all sample data | `utils/remove_all_sample_data.dart` | Menu hidden + dialog/API guard |
| Comprehensive duplicate cleanup | `utils/comprehensive_duplicate_cleanup.dart` | Menu hidden + dialog + `cleanupAll()` guard |
| Orphan cleanup (delete mode) | `services/orphan_cleanup_service.dart` | Menu hidden + service guard |
| Seed general maintenance assets | `screens/admin/seed_general_assets_screen.dart`, technician menu, asset picker | Menu/button hidden + screen + seeder guard |
| Delete seeded facility assets | `utils/seed_general_maintenance_assets.dart` | `deleteAllGeneralMaintenanceAssets()` guard |

### GATE — Dev diagnostics (non-destructive, admin-only)

Hidden in release; available in debug or with `ENABLE_DEV_TOOLS=true`.

| Item | Location | Gate applied |
|------|----------|--------------|
| Assignment diagnostic screen | `screens/admin/assignment_diagnostic_screen.dart` | Admin menu |
| Performance diagnostic screen | `screens/admin/performance_diagnostic_screen.dart` | Admin menu |
| Duplicate monitor screen | `screens/admin/duplicate_monitor_screen.dart` | Desktop admin menu |
| User ID diagnostic | `utils/user_id_diagnostic.dart` | Admin menu + dialog guard |
| Duplicate data diagnostic | `utils/duplicate_data_diagnostic.dart` | Dialog guard (menu item has no handler — see notes) |
| Cleanup unknown users screen | `screens/admin/cleanup_users_screen.dart` | Admin menu |
| Fix unknown admin utility | `utils/fix_unknown_admin.dart` | Admin menu + dialog guard |
| Orphan cleanup (dry run) | `services/orphan_cleanup_service.dart` | Admin menu + service guard |

### KEEP — Intentionally available in production

| Item | Rationale |
|------|-----------|
| Admin dashboard, user/company management, reporting, inventory | Core product features |
| Demo user login | Already gated by `AppConfig.isDemoMode` (`DEMO_MODE=true` **and** `kDebugMode`) |
| Supabase dev URL/key fallbacks | Only when `AppConfig.isDebugMode`; release requires `--dart-define` credentials |
| `PerformanceMonitor` | Disabled by default in release (`enabled = kDebugMode`) |
| Verbose logging / `printConfig()` | Debug-oriented; no production UI entry points |

### DEAD CODE IN BINARY — Compiled but not routed

These files are **not linked from production navigation** but still ship in the app binary until deleted in a future cleanup pass.

| Category | Paths |
|----------|-------|
| Demo screens | `lib/screens/demo/enhanced_asset_demo_screen.dart`, `professional_asset_demo_screen.dart` |
| Settings test screens | `lib/screens/settings/api_test_screen.dart`, `connectivity_test_screen.dart`, `quick_network_test_screen.dart`, `simple_network_test_screen.dart`, `uri_test_screen.dart` |
| DAM integration (unused) | `lib/screens/settings/dam_config_screen.dart`, `dam_integration_screen.dart`, `services/hybrid_dam_service.dart` |
| Web admin portal | `lib/screens/web_admin/web_admin_portal_screen.dart`, `lib/utils/web_router.dart` |
| Orphaned utilities | Various items from dead-code audit (hyper-speed cache, duplicate analytics fork, etc.) |

**Recommendation:** Delete Tier-1 dead code (~4k LOC from prior audit) in a follow-up PR to shrink binary size and attack surface.

---

## Defense layers

1. **UI** — Admin/technician menus omit gated items when flags are false.
2. **Handlers** — Menu `onSelected` rejects gated action IDs even if invoked programmatically.
3. **Entry points** — `show*Dialog()` methods and service `run()` / `cleanupAll()` / `wipe*` methods throw or no-op when flags are false.

---

## Enabling tools for internal QA (staging only)

```bash
# Non-destructive dev tools only (diagnostics, seeding)
flutter run --dart-define=ENABLE_DEV_TOOLS=true

# Include destructive wipe/delete utilities (use staging database only)
flutter run \
  --dart-define=ENABLE_DEV_TOOLS=true \
  --dart-define=ENABLE_DESTRUCTIVE_ADMIN_TOOLS=true
```

Never add these defines to `scripts/defines.production.json` or App Store release pipelines.

---

## Known gaps / follow-ups

1. **Data Sync Diagnostic** menu item exists in admin mobile menu but has **no handler** — dead menu entry (harmless in release since menu is hidden).
2. **Dead code** listed above remains in the binary; gating does not remove it from compilation.
3. **`AUTO_POPULATE_USERS` / `AUTO_CREATE_USERS_ON_LOGIN`** dart-defines default to `false`; no additional gating added (low risk if defines file stays clean).
4. Consider splitting admin app flavor so destructive utilities live in a separate internal target.

---

## Files changed in this pass

- `lib/config/release_safety.dart` (new)
- `lib/screens/admin/admin_main_screen.dart`
- `lib/screens/admin/seed_general_assets_screen.dart`
- `lib/screens/technician/technician_main_screen.dart`
- `lib/widgets/enhanced_asset_selection_widget.dart`
- `lib/utils/complete_database_wipe.dart`
- `lib/utils/kill_duplicates_now.dart`
- `lib/utils/database_reset_utility.dart`
- `lib/utils/remove_all_sample_data.dart`
- `lib/utils/fix_unknown_admin.dart`
- `lib/utils/user_id_diagnostic.dart`
- `lib/utils/duplicate_data_diagnostic.dart`
- `lib/utils/comprehensive_duplicate_cleanup.dart`
- `lib/utils/seed_general_maintenance_assets.dart`
- `lib/services/orphan_cleanup_service.dart`
