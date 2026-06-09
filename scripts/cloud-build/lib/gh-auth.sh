#!/usr/bin/env bash
# GitHub CLI presence and session validation.

if [[ -n "${CLOUD_BUILD_GH_AUTH_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
CLOUD_BUILD_GH_AUTH_LOADED=1

set -euo pipefail

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

GH_HOSTNAME=""
GH_USERNAME=""

parse_auth_json_hostname_username() {
  local json="$1"
  GH_HOSTNAME="$(printf '%s' "$json" | jq -r '.hostname // empty')"
  GH_USERNAME="$(printf '%s' "$json" | jq -r '.username // empty')"
}

parse_auth_json_hosts() {
  local json="$1"
  GH_HOSTNAME="$(printf '%s' "$json" | jq -r '.hosts."github.com"[0].host // "github.com"')"
  GH_USERNAME="$(printf '%s' "$json" | jq -r '.hosts."github.com"[0].login // empty')"
}

resolve_username_via_api() {
  if GH_USERNAME="$(gh api user --jq .login 2>/dev/null)"; then
    GH_HOSTNAME="${GH_HOSTNAME:-github.com}"
    return 0
  fi
  return 1
}

interactive_gh_login_trap() {
  log "GitHub session is not authorized. Starting interactive gh auth login..."
  log "Grant scopes: repo, workflow, read:org (minimum for fork, contents API, and Actions)."
  gh auth login
}

ensure_gh_cli() {
  require_cmd gh
  require_cmd jq
  log "gh CLI present: $(gh --version | head -1)"
}

ensure_gh_auth() {
  ensure_gh_cli

  local auth_json=""
  if auth_json="$(gh auth status --json hostname,username 2>/dev/null)"; then
    parse_auth_json_hostname_username "$auth_json"
  elif auth_json="$(gh auth status --json hosts 2>/dev/null)"; then
    parse_auth_json_hosts "$auth_json"
  fi

  if [[ -z "${GH_USERNAME}" ]]; then
    resolve_username_via_api || true
  fi

  if [[ -z "${GH_USERNAME}" ]]; then
    interactive_gh_login_trap
    ensure_gh_auth
    return
  fi

  local state=""
  if auth_json="$(gh auth status --json hosts 2>/dev/null)"; then
    state="$(printf '%s' "$auth_json" | jq -r '.hosts."github.com"[0].state // empty')"
  fi

  if [[ "${state}" == "failed" ]]; then
    interactive_gh_login_trap
    ensure_gh_auth
    return
  fi

  GH_HOSTNAME="${GH_HOSTNAME:-github.com}"
  log "GitHub session OK: ${GH_USERNAME}@${GH_HOSTNAME}"
}

get_gh_username() {
  [[ -n "${GH_USERNAME}" ]] || ensure_gh_auth
  printf '%s' "${GH_USERNAME}"
}

get_gh_hostname() {
  [[ -n "${GH_HOSTNAME}" ]] || ensure_gh_auth
  printf '%s' "${GH_HOSTNAME}"
}
