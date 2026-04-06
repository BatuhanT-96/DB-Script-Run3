#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly SQL_ROOT_REL="DB-Scripts-Run"
readonly SQL_ROOT="${REPO_ROOT}/${SQL_ROOT_REL}"

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found in PATH: ${cmd}"
}

require_non_empty_env() {
  local name="$1"
  local value="${!name:-}"
  [[ -n "$value" ]] || die "Required variable is missing or empty: ${name}"
}

validate_enum_value() {
  local value="$1"
  local name="$2"
  shift 2
  local allowed
  for allowed in "$@"; do
    if [[ "$value" == "$allowed" ]]; then
      return 0
    fi
  done
  die "Invalid ${name}: '${value}'. Allowed values: $*"
}

validate_regex_value() {
  local value="$1"
  local name="$2"
  local pattern="$3"
  [[ "$value" =~ $pattern ]] || die "Invalid ${name}: '${value}'"
}

canonicalize_path() {
  local path_input="$1"
  python3 - "$path_input" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

line_count_for_offset() {
  local file="$1"
  local offset="$2"
  python3 - "$file" "$offset" <<'PY'
import sys
path = sys.argv[1]
offset = int(sys.argv[2])
with open(path, 'rb') as fh:
    data = fh.read()
print(data[:offset].count(b'\n') + 1)
PY
}
