#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=scripts/resolve_connection.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resolve_connection.sh"

main() {
  require_command "psql"

  require_non_empty_env "RESOLVED_SQL_FILE"
  require_non_empty_env "DB_TYPE"
  require_non_empty_env "ENVIRONMENT"
  require_non_empty_env "DB_NAME"

  resolve_connection

  [[ -f "${RESOLVED_SQL_FILE}" ]] || die "Resolved SQL file is missing: ${RESOLVED_SQL_FILE}"

  log_info "Executing Postgre SQL file: ${RESOLVED_SQL_RELATIVE:-${RESOLVED_SQL_FILE}}"

  export PGPASSWORD="${DB_PASSWORD}"
  psql \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --username="${DB_USER}" \
    --dbname="${DB_DATABASE}" \
    --file="${RESOLVED_SQL_FILE}" \
    --set=ON_ERROR_STOP=1 \
    --no-psqlrc \
    --quiet

  unset PGPASSWORD
  log_info "Postgre SQL execution completed successfully."
}

main "$@"
