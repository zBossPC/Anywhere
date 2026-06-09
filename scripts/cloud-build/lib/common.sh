#!/usr/bin/env bash
# Shared helpers for cloud-compile automation.

if [[ -n "${CLOUD_BUILD_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
CLOUD_BUILD_COMMON_LOADED=1

set -euo pipefail

readonly CLOUD_BUILD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly WORKSPACE_ROOT="$(cd "${CLOUD_BUILD_ROOT}/../.." && pwd)"
readonly WORKFLOW_TEMPLATE="${CLOUD_BUILD_ROOT}/workflows/build.yml"
readonly WORKFLOW_REMOTE_PATH=".github/workflows/build.yml"
readonly ARTIFACT_NAME="Anywhere-Unsigned-IPA"
readonly DEFAULT_UPSTREAM="NodePassProject/Anywhere"
readonly DEFAULT_SCHEME="Anywhere"
readonly DEFAULT_BRANCH="main"

log() {
  printf '[cloud-compile] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: ${cmd}"
}

base64_encode_file() {
  local file="$1"
  if base64 --help 2>&1 | grep -q -- '-w'; then
    base64 -w0 "$file"
  else
    base64 <"$file" | tr -d '\n'
  fi
}

repo_owner() {
  local slug="$1"
  echo "${slug%%/*}"
}

repo_name() {
  local slug="$1"
  echo "${slug#*/}"
}
