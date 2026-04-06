#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

resolve_connection() {
  require_non_empty_env "DB_TYPE"
  require_non_empty_env "ENVIRONMENT"
  require_non_empty_env "DB_NAME"

  local prefix host_var port_var user_var pass_var
  case "${DB_TYPE}:${ENVIRONMENT}" in
    Postgre:Test) prefix="POSTGRE_TEST" ;;
    Postgre:Prod) prefix="POSTGRE_PROD" ;;
    Oracle:Test) prefix="ORACLE_TEST" ;;
    Oracle:Prod) prefix="ORACLE_PROD" ;;
    *) die "Unsupported DB_TYPE/ENVIRONMENT combination: ${DB_TYPE}/${ENVIRONMENT}" ;;
  esac

  host_var="${prefix}_HOST"
  port_var="${prefix}_PORT"
  user_var="${prefix}_USER"
  pass_var="${prefix}_PASSWORD"

  require_non_empty_env "${host_var}"
  require_non_empty_env "${port_var}"
  require_non_empty_env "${user_var}"
  require_non_empty_env "${pass_var}"

  local db_host db_port db_user db_password
  db_host="${!host_var}"
  db_port="${!port_var}"
  db_user="${!user_var}"
  db_password="${!pass_var}"

  validate_regex_value "${db_port}" "${port_var}" '^[0-9]{1,5}$'

  export DB_HOST="${db_host}"
  export DB_PORT="${db_port}"
  export DB_USER="${db_user}"
  export DB_PASSWORD="${db_password}"

  if [[ "${DB_TYPE}" == "Postgre" ]]; then
    export DB_DATABASE="${DB_NAME}"
    return 0
  fi

  local service_var sid_var service_name sid_value descriptor
  service_var="${prefix}_SERVICE_NAME"
  sid_var="${prefix}_SID"
  service_name="${!service_var:-}"
  sid_value="${!sid_var:-}"

  if [[ -n "${service_name}" && -n "${sid_value}" ]]; then
    die "Only one of ${service_var} or ${sid_var} can be set"
  fi

  if [[ -n "${service_name}" ]]; then
    descriptor="//${db_host}:${db_port}/${service_name}"
  elif [[ -n "${sid_value}" ]]; then
    descriptor="${db_host}:${db_port}:${sid_value}"
  else
    # Fallback to DB_NAME to preserve simple usage while supporting explicit service/SID variables.
    descriptor="//${db_host}:${db_port}/${DB_NAME}"
  fi

  export DB_CONNECT_DESCRIPTOR="${descriptor}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  resolve_connection "$@"
  log_info "Connection variables resolved for ${DB_TYPE}/${ENVIRONMENT}."
fi
