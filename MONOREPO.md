# Monorepo layout

| Path | Role |
|------|------|
| `packages/cmms_core` | Shared Dart package: models, services, Supabase, providers, screens, assets. |
| `apps/requestor_cmms` | Store build for **requestor** users only. |
| `apps/technician_cmms` | Store build for **technician / manager / admin** users. |

## Run

```bash
cd apps/requestor_cmms && flutter pub get && flutter run
```

```bash
cd apps/technician_cmms && flutter pub get && flutter run
```

## Develop against the library only

```bash
cd packages/cmms_core && flutter pub get && flutter run
```

That runs the default entry (requestor) from `cmms_core/lib/main.dart` for quick iteration.

## Tests

```bash
cd packages/cmms_core && flutter test
cd apps/requestor_cmms && flutter test
cd apps/technician_cmms && flutter test
```

### Integration tests (auth + submit)

Always-on integration tests live under `packages/cmms_core/test/integration/`. They do not require Supabase credentials.

```bash
./scripts/run_integration_tests.sh
```

Optional live Supabase auth/submit checks (self-skip when unset):

```bash
export SUPABASE_URL=...
export SUPABASE_ANON_KEY=...
export INTEGRATION_REQUESTOR_EMAIL=...
export INTEGRATION_REQUESTOR_PASSWORD=...
./scripts/run_integration_tests.sh
```

GitHub Actions runs `test/integration/` on every push/PR. Add the four env vars above as repository secrets to enable live Supabase tests in CI.

## Optional: Melos

If you use [Melos](https://melos.invertase.dev/), from the repo root run `melos bootstrap` to link packages.

## Images and `assets/`

UI images live under `packages/cmms_core/assets/`. The shell apps do **not** copy those files to their own `assets/` folder, so in code you must load them with `package: kCmmsCoreAssetPackage` (see `cmms_core/lib/utils/cmms_package_assets.dart`) on `Image.asset` and `AssetImage`. Otherwise Flutter looks in the **shell** bundle only and logos/backgrounds appear missing.

## iOS / Android

Each app has its own `applicationId` / bundle id (`com.beelectric.cmms.requestor_cmms` and `com.beelectric.cmms.technician_cmms`). Change them in each app’s `android/` and `ios/` when you register separate store listings.

## Role behaviour

- **Requestor app:** only the `requestor` role is allowed; other roles see a sign-out message.
- **Technician app:** `technician`, `manager`, and `admin` get the same flows as before; `requestor` is directed to the requestor app.

Configuration (Supabase) still comes from `cmms_core`’s `AppConfig` and `--dart-define=...` flags.

Production release builds use `scripts/defines.production.json` (see `scripts/defines.production.json.example`). **`ENABLE_PM_OCCURRENCES=true`** enables Option A PM in store binaries. See `docs/PM_MIGRATION_GUIDE.md`.
