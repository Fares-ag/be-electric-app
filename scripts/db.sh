#!/usr/bin/env bash
# Direct Postgres CLI for Supabase (psql).
#
# Setup:
#   cp scripts/db.env.example scripts/db.env
#   # Edit scripts/db.env with your database password from Supabase Dashboard
#
# Usage:
#   ./scripts/db.sh check
#   ./scripts/db.sh shell
#   ./scripts/db.sh query "SELECT count(*) FROM work_orders"
#   ./scripts/db.sh run scripts/sql/list_work_orders.sql
#   ./scripts/db.sh migrate-support
#   ./scripts/db.sh verify-support
#   ./scripts/db.sh migrate-pm-tasks-technician-update
#   ./scripts/db.sh verify-pm-tasks-technician-update
#   ./scripts/db.sh migrate-inventory-technician-select
#   ./scripts/db.sh verify-inventory-technician-select
#   ./scripts/db.sh migrate-technician-insert-field-chargers
#   ./scripts/db.sh verify-technician-insert-field-chargers
#   ./scripts/db.sh report-orphan-assignments
#   ./scripts/db.sh migrate-prevent-orphan-assignments
#   ./scripts/db.sh verify-orphan-assignments
#   ./scripts/db.sh support-requests
#   ./scripts/db.sh tables
#   ./scripts/db.sh users
#   ./scripts/db.sh work-orders
#   ./scripts/db.sh assets

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/db.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a
fi

build_database_url() {
  if [[ -n "${DATABASE_URL:-}" ]]; then
    return 0
  fi
  if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
    return 1
  fi

  local ref="${SUPABASE_PROJECT_REF:-}"
  if [[ -z "$ref" && -n "${SUPABASE_URL:-}" ]]; then
    ref="$(echo "$SUPABASE_URL" | sed -E 's|https?://||; s|\.supabase\.co.*||')"
  fi

  local host="${SUPABASE_DB_HOST:-}"
  if [[ -z "$host" && -n "$ref" ]]; then
    host="db.${ref}.supabase.co"
  fi

  local port="${SUPABASE_DB_PORT:-5432}"
  local user="${SUPABASE_DB_USER:-postgres}"
  local db="${SUPABASE_DB_NAME:-postgres}"

  if [[ -z "$host" ]]; then
    return 1
  fi

  DATABASE_URL="postgresql://${user}:${SUPABASE_DB_PASSWORD}@${host}:${port}/${db}"
}

find_psql() {
  if command -v psql >/dev/null 2>&1; then
    command -v psql
    return 0
  fi
  for p in /opt/homebrew/opt/libpq/bin/psql /usr/local/opt/libpq/bin/psql; do
    if [[ -x "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

find_node_db_cli() {
  local cli="$SCRIPT_DIR/db-cli/db.mjs"
  if [[ -f "$cli" ]] && command -v node >/dev/null 2>&1; then
    if [[ -d "$SCRIPT_DIR/db-cli/node_modules/postgres" ]]; then
      echo "$cli"
      return 0
    fi
  fi
  # fnm node in user home
  if [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
    export PATH="$HOME/.local/share/fnm:$PATH"
    # shellcheck disable=SC1090
    eval "$("$HOME/.local/share/fnm/fnm" env 2>/dev/null || true)"
    if [[ -f "$cli" ]] && command -v node >/dev/null 2>&1 && [[ -d "$SCRIPT_DIR/db-cli/node_modules/postgres" ]]; then
      echo "$cli"
      return 0
    fi
  fi
  return 1
}

PSQL_BIN="$(find_psql || true)"
NODE_CLI="$(find_node_db_cli || true)"
USE_DOCKER="${DB_USE_DOCKER:-}"

require_psql() {
  if [[ -n "$PSQL_BIN" ]]; then
    return 0
  fi
  if [[ -n "$NODE_CLI" ]]; then
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    USE_DOCKER=1
    return 0
  fi
  echo "Database CLI not ready." >&2
  echo "Run (no admin): ./scripts/install_db_cli.sh" >&2
  exit 1
}

require_db_config() {
  if ! build_database_url; then
    echo "Missing database credentials." >&2
    echo "Create $ENV_FILE from db.env.example and set DATABASE_URL or SUPABASE_DB_PASSWORD." >&2
    exit 1
  fi
}

run_node_cli() {
  node "$NODE_CLI" "$@"
}

run_psql() {
  require_psql
  require_db_config

  if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
    run_node_cli "$@"
    return
  fi

  if [[ "$USE_DOCKER" == "1" ]]; then
    docker run --rm -i postgres:16-alpine psql "$DATABASE_URL" "$@"
    return
  fi

  "$PSQL_BIN" "$DATABASE_URL" "$@"
}

run_psql_file() {
  local file="$1"
  require_psql
  require_db_config

  if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
    run_node_cli run "$file"
    return
  fi

  if [[ "$USE_DOCKER" == "1" ]]; then
    docker run --rm -i \
      -v "${file}:/sql/query.sql:ro" \
      postgres:16-alpine \
      psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f /sql/query.sql
    return
  fi

  "$PSQL_BIN" "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
}

run_psql_interactive() {
  require_psql
  require_db_config

  if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
    echo "Interactive shell needs psql. Use:" >&2
    echo "  ./scripts/db.sh query \"SELECT ...\"" >&2
    echo "  ./scripts/db.sh users" >&2
    exit 1
  fi

  if [[ "$USE_DOCKER" == "1" ]]; then
    docker run --rm -it postgres:16-alpine psql "$DATABASE_URL"
    return
  fi

  "$PSQL_BIN" "$DATABASE_URL"
}

cmd="${1:-help}"

case "$cmd" in
  help|-h|--help)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  check)
    if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
      run_node_cli check
    else
      run_psql -v ON_ERROR_STOP=1 -c "SELECT current_database() AS db, current_user AS user, now() AS server_time;"
      echo "Connection OK."
    fi
    ;;
  shell|psql)
    run_psql_interactive
    ;;
  query|q)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: $0 query \"SELECT ...\"" >&2
      exit 1
    fi
    if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
      run_node_cli query "$2"
    else
      run_psql -v ON_ERROR_STOP=1 -c "$2"
    fi
    ;;
  run|file|f)
    file="${2:-}"
    if [[ -z "$file" || ! -f "$file" ]]; then
      echo "Usage: $0 run path/to/file.sql" >&2
      exit 1
    fi
    run_psql_file "$file"
    ;;
  install)
    exec "$SCRIPT_DIR/install_db_cli.sh"
    ;;
  docker-check)
    USE_DOCKER=1
    run_psql -v ON_ERROR_STOP=1 -c "SELECT current_database() AS db, current_user AS user, now() AS server_time;"
    echo "Docker psql connection OK."
    ;;
  tables)
    if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
      run_node_cli tables
    else
      run_psql -v ON_ERROR_STOP=1 -c "
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_type = 'BASE TABLE'
      ORDER BY table_name;"
    fi
    ;;
  users)
    if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
      run_node_cli users
    else
      run_psql -v ON_ERROR_STOP=1 -c "
      SELECT id, email, name, role, companyId, isActive
      FROM users
      ORDER BY email
      LIMIT 50;"
    fi
    ;;
  work-orders|wo)
    if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
      run_node_cli work-orders
    else
      run_psql -v ON_ERROR_STOP=1 -c "
      SELECT id, ticketNumber, status, requestorId, companyId, createdAt
      FROM work_orders
      ORDER BY createdAt DESC
      LIMIT 25;"
    fi
    ;;
  assets)
    if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
      run_node_cli assets
    else
      run_psql -v ON_ERROR_STOP=1 -c "
      SELECT id, name, manufacturer, companyId, location, status
      FROM assets
      ORDER BY name
      LIMIT 50;"
    fi
    ;;
  companies)
    if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
      run_node_cli companies
    else
      run_psql -v ON_ERROR_STOP=1 -c "
      SELECT id, name, createdAt
      FROM companies
      ORDER BY name
      LIMIT 50;"
    fi
    ;;
  migrate-support|support-migrate)
    run_psql_file "$REPO_ROOT/scripts/sql/migrate_support_requests.sql"
    ;;
  verify-support|support-verify)
    run_psql_file "$REPO_ROOT/scripts/sql/verify_support_requests.sql"
    ;;
  migrate-pm-tasks-technician-update|pm-tasks-technician-update-migrate)
    run_psql_file "$REPO_ROOT/scripts/sql/migrate_pm_tasks_technician_update_rls.sql"
    ;;
  verify-pm-tasks-technician-update|pm-tasks-technician-update-verify)
    run_psql_file "$REPO_ROOT/scripts/sql/verify_pm_tasks_technician_update_rls.sql"
    ;;
  migrate-inventory-technician-select|inventory-technician-select-migrate)
    run_psql_file "$REPO_ROOT/scripts/sql/migrate_inventory_technician_select_rls.sql"
    ;;
  verify-inventory-technician-select|inventory-technician-select-verify)
    run_psql_file "$REPO_ROOT/scripts/sql/verify_inventory_technician_select_rls.sql"
    ;;
  migrate-technician-insert-field-chargers|technician-insert-field-chargers-migrate)
    run_psql_file "$REPO_ROOT/scripts/sql/migrate_technician_insert_field_chargers.sql"
    ;;
  verify-technician-insert-field-chargers|technician-insert-field-chargers-verify)
    run_psql_file "$REPO_ROOT/scripts/sql/verify_technician_insert_field_chargers.sql"
    ;;
  report-orphan-assignments|orphan-assignments-report)
    run_psql_file "$REPO_ROOT/scripts/sql/report_orphan_technician_assignments.sql"
    ;;
  migrate-prevent-orphan-assignments|orphan-assignments-migrate)
    run_psql_file "$REPO_ROOT/scripts/sql/migrate_prevent_orphan_technician_assignments.sql"
    ;;
  verify-orphan-assignments|orphan-assignments-verify)
    run_psql_file "$REPO_ROOT/scripts/sql/verify_orphan_technician_assignments.sql"
    ;;
  verify-requestor-ppm|requestor-ppm-verify)
    run_psql_file "$REPO_ROOT/scripts/sql/verify_requestor_ppm_backend.sql"
    ;;
  support-requests|support)
    if [[ -n "$NODE_CLI" && -z "$PSQL_BIN" ]]; then
      run_node_cli query "
      SELECT id, type, status, \"createdBy\", \"createdAt\"
      FROM support_requests
      ORDER BY \"createdAt\" DESC
      LIMIT 25;"
    else
      run_psql -v ON_ERROR_STOP=1 -c "
      SELECT id, type, status, \"createdBy\", \"createdAt\"
      FROM support_requests
      ORDER BY \"createdAt\" DESC
      LIMIT 25;"
    fi
    ;;
  supabase-shell)
    if ! command -v supabase >/dev/null 2>&1; then
      echo "supabase CLI not found. Install: brew install supabase/tap/supabase" >&2
      exit 1
    fi
    cd "$REPO_ROOT"
    supabase db shell
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Run: $0 help" >&2
    exit 1
    ;;
esac
