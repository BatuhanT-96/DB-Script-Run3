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

  local sql_root_real candidate relative expected_prefix candidate_real

  sql_root_real="$(canonicalize_path "${SQL_ROOT}")"
  [[ -d "${sql_root_real}" ]] || die "SQL root directory does not exist: ${SQL_ROOT_REL}"

  relative="${DB_TYPE}/${ENVIRONMENT}/${SCRIPT_TYPE}/${DB_NAME}/${SCRIPT_NAME}"
  candidate="${SQL_ROOT}/${relative}"

  [[ -e "${candidate}" ]] || die "SQL file not found at expected path: ${SQL_ROOT_REL}/${relative}"
  [[ -f "${candidate}" ]] || die "Resolved SQL path is not a regular file: ${SQL_ROOT_REL}/${relative}"
  [[ ! -L "${candidate}" ]] || die "Symlink SQL files are not allowed: ${SQL_ROOT_REL}/${relative}"
  [[ "${SCRIPT_NAME}" == *.sql ]] || die "SCRIPT_NAME must end with .sql"

  candidate_real="$(canonicalize_path "${candidate}")"
  expected_prefix="${sql_root_real}/"

  [[ "${candidate_real}" == "${expected_prefix}"* ]] || die "Resolved SQL file escapes allowed root directory"

  printf 'RESOLVED_SQL_FILE=%q\n' "${candidate_real}"
  printf 'RESOLVED_SQL_RELATIVE=%q\n' "${SQL_ROOT_REL}/${relative}"
  log_info "Resolved SQL file: ${SQL_ROOT_REL}/${relative}" >&2
}

main "$@"
