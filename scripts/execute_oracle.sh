#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=scripts/resolve_connection.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resolve_connection.sh"

main() {
  require_command "sqlplus"

  require_non_empty_env "RESOLVED_SQL_FILE"
  require_non_empty_env "DB_TYPE"
  require_non_empty_env "ENVIRONMENT"
  require_non_empty_env "DB_NAME"

  resolve_connection

  [[ -f "${RESOLVED_SQL_FILE}" ]] || die "Resolved SQL file is missing: ${RESOLVED_SQL_FILE}"

  log_info "Executing Oracle SQL file: ${RESOLVED_SQL_RELATIVE:-${RESOLVED_SQL_FILE}}"

  sqlplus -s /nolog <<SQL
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET ECHO OFF
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
CONNECT ${DB_USER}/"${DB_PASSWORD}"@${DB_CONNECT_DESCRIPTOR}
@${RESOLVED_SQL_FILE}
EXIT SUCCESS
SQL

  log_info "Oracle SQL execution completed successfully."
}

main "$@"
