# be-electric-app — Be Electric CMMS Mobile Application

A Flutter-based Computerized Maintenance Management System (CMMS) mobile application for EV charger maintenance management.

## Overview

Be Electric is a comprehensive maintenance management solution designed for managing EV charger maintenance requests, work orders, and asset tracking.

## Features

- **Multi-tenant Support**: Isolated data per company
- **Role-based Access**: Requestor, Technician, Manager, and Admin roles
- **Real-time Updates**: Supabase real-time synchronization
- **Work Order Management**: Create, track, and manage maintenance requests
- **Asset Management**: Track and manage EV chargers and equipment
- **Photo Attachments**: Attach photos to maintenance requests
- **Analytics Dashboard**: View maintenance statistics and performance metrics

## Technology Stack

- **Framework**: Flutter
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **State Management**: Provider
- **Real-time**: Supabase Realtime

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Supabase account and project

### Installation

1. Clone the repository.
2. Open a **shell app** and install dependencies:
   ```bash
   cd apps/requestor_cmms
   flutter pub get
   flutter run
   ```
   For the technician build:
   ```bash
   cd apps/technician_cmms
   flutter pub get
   flutter run
   ```
   Shared code is in `packages/cmms_core` (see **`MONOREPO.md`**).

3. Configure Supabase:
   - For local dev, defaults in `packages/cmms_core/lib/config/app_config.dart` are used.
   - For production, use `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...` (see `qauto-cmms-main/.env.example` and `qauto-cmms-main/docs/PRODUCTION.md` if present).
   - Schema: Supabase CLI under `qauto-cmms-main/supabase/` — `npx supabase link --project-ref <ref>` then `npx supabase db pull` (see `supabase/migrations/README.md`).

## Database Setup

- **Schema (Supabase):** From the repo, run `npx supabase link --project-ref <your-project-ref>` then `npx supabase db pull`. Migrations live in `qauto-cmms-main/supabase/migrations/` or the project’s `supabase/migrations/` folder.
- Alternatively, run your SQL migration scripts in the Supabase SQL Editor (e.g. `supabase_migration.sql`, `add_company_support.sql`, `fix_user_lookup_rls.sql`).

## Project Structure

- `packages/cmms_core/lib/` — screens, models, services, providers, widgets, utils
- `apps/requestor_cmms/` — requestor-only store build
- `apps/technician_cmms/` — technician / manager / admin store build

## License

Copyright © 2025 Be Electric


