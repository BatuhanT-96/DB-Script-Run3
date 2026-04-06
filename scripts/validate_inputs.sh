#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

main() {
  require_non_empty_env "DB_TYPE"
  require_non_empty_env "ENVIRONMENT"
  require_non_empty_env "SCRIPT_TYPE"
  require_non_empty_env "DB_NAME"
  require_non_empty_env "SCRIPT_NAME"

  validate_enum_value "${DB_TYPE}" "DB_TYPE" "Oracle" "Postgre"
  validate_enum_value "${ENVIRONMENT}" "ENVIRONMENT" "Test" "Prod"
  validate_enum_value "${SCRIPT_TYPE}" "SCRIPT_TYPE" "DDL" "DML"

  validate_regex_value "${DB_NAME}" "DB_NAME" '^[A-Za-z0-9_-]+$'
  validate_regex_value "${SCRIPT_NAME}" "SCRIPT_NAME" '^[A-Za-z0-9_.-]+\.sql$'

  [[ "${SCRIPT_NAME}" != *"/"* ]] || die "SCRIPT_NAME must be file name only; path separators are not allowed"
  [[ "${SCRIPT_NAME}" != *".."* ]] || die "SCRIPT_NAME must not contain '..'"
  [[ "${DB_NAME}" != *".."* ]] || die "DB_NAME must not contain '..'"

  log_info "Input validation completed successfully."
}

main "$@"
