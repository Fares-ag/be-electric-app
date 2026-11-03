#!/usr/bin/env bash
# Runs requestor auth/submit integration tests.
#
# Always runs (no skip): test/integration/* except live Supabase auth tests
# self-skip when env vars are absent.
#
# Optional live auth/submit checks — set all of:
#   SUPABASE_URL
#   SUPABASE_ANON_KEY
#   INTEGRATION_REQUESTOR_EMAIL
#   INTEGRATION_REQUESTOR_PASSWORD
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/packages/cmms_core"

echo "Running cmms_core integration tests..."
flutter test test/integration/ --reporter expanded

echo "Integration test run complete."
