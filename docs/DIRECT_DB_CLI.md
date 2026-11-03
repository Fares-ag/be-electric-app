# Direct database CLI (Supabase Postgres)

Use `scripts/db.sh` against your Supabase Postgres database for debugging, App Review seeding, and ad-hoc queries.

## 1. Install (no admin / no Homebrew)

This Mac account cannot run `sudo`, so **Homebrew will not install**. Use the project installer instead:

```bash
cd /path/to/Be-electric
./scripts/install_db_cli.sh
source ~/.zprofile
```

That installs **fnm + Node 20** under `~/.local/share/fnm` and the Node-based DB CLI in `scripts/db-cli/` (no `psql` required).

Verify:

```bash
./scripts/db.sh check
```

If you see `Missing DATABASE_URL`, configure credentials in step 3 below — the CLI itself is working.

### Optional: Homebrew + psql (admin Mac only)

```bash
brew install libpq
brew link --force libpq
psql --version
```

Alternative: `brew install postgresql@16`

Optional Supabase CLI (different path — uses linked project):

```bash
brew install supabase/tap/supabase
```

Supabase Dashboard → **Project Settings** → **Database** → **Database password** (reset if needed).

Connection string (URI) is on the same page. For CLI, prefer **direct** connection:

`postgresql://postgres:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres`

Project ref from your URL: `https://[PROJECT_REF].supabase.co`

## 3. Configure (do not commit)

```bash
cp scripts/db.env.example scripts/db.env
```

Edit `scripts/db.env` — simplest:

```bash
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@db.YOUR_PROJECT_REF.supabase.co:5432/postgres
```

Or:

```bash
SUPABASE_PROJECT_REF=your_project_ref
SUPABASE_DB_PASSWORD=your_password
```

## 4. Commands

```bash
chmod +x scripts/db.sh

./scripts/db.sh check          # test connection
./scripts/db.sh shell          # interactive psql
./scripts/db.sh tables         # list public tables
./scripts/db.sh users          # sample users
./scripts/db.sh work-orders    # recent work orders
./scripts/db.sh assets         # sample assets
./scripts/db.sh companies      # companies

./scripts/db.sh query "SELECT count(*) FROM work_orders"
./scripts/db.sh run scripts/sql/app_review_checklist.sql
./scripts/db.sh run scripts/sql/list_chargers_by_company.sql

# Be Electric Support (Know How / Commissioning)
./scripts/db.sh migrate-support    # support_requests table + RLS + storage
./scripts/db.sh migrate-pm-tasks-technician-update  # T-001: pm_tasks technician UPDATE RLS
./scripts/db.sh migrate-inventory-technician-select  # T-002: inventory_items technician SELECT RLS
./scripts/db.sh verify-inventory-technician-select   # confirm parts catalog policy
./scripts/db.sh report-orphan-assignments            # T-003: read-only orphan WO/PM report
./scripts/db.sh migrate-prevent-orphan-assignments   # T-003: scrub on delete + validation triggers
./scripts/db.sh verify-orphan-assignments            # T-003: prevention + legacy orphan counts
./scripts/db.sh verify-support
./scripts/db.sh run scripts/sql/verify_requestor_backend.sql
./scripts/db.sh support-requests   # recent rows
```

## 5. App Review demo setup (SQL Editor or CLI)

1. Run checklist:

   ```bash
   ./scripts/db.sh run scripts/sql/app_review_checklist.sql
   ```

2. Ensure demo **requestor** user exists in `users` with `role = 'requestor'` and a `companyId`.

3. Ensure that company has assets with `manufacturer` containing `Siemens` and `Kostad`.

4. Create auth user in Supabase **Authentication** with the same email as `users.email` (or use existing).

5. Paste credentials into `docs/APP_STORE_REVIEW_NOTES.md`.

## 6. Supabase CLI alternative

If the project is linked:

```bash
cd /path/to/Be-electric
npx supabase link --project-ref YOUR_PROJECT_REF
./scripts/db.sh supabase-shell
```

## Security

- Never commit `scripts/db.env` or database passwords.
- Use read-only queries in production when possible.
- Prefer Supabase SQL Editor for one-off writes if you are not comfortable with CLI.
