#!/usr/bin/env bash
# Fork upstream repository into the authenticated user's namespace.

if [[ -n "${CLOUD_BUILD_FORK_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
CLOUD_BUILD_FORK_LOADED=1

set -euo pipefail

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=gh-auth.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gh-auth.sh"

fork_exists_for_user() {
  local user="$1"
  local repo_name="$2"
  gh api "repos/${user}/${repo_name}" --silent >/dev/null 2>&1
}

ensure_fork() {
  local upstream="${1:-${DEFAULT_UPSTREAM}}"
  local user repo_name fork_slug

  ensure_gh_auth
  user="$(get_gh_username)"
  repo_name="$(repo_name "$upstream")"
  fork_slug="${user}/${repo_name}"

  if fork_exists_for_user "$user" "$repo_name"; then
    log "Fork already exists: ${fork_slug}"
    printf '%s' "${fork_slug}"
    return 0
  fi

  log "Forking ${upstream} -> ${user} (headless, no clone)..."
  if gh repo fork "${upstream}" --clone=false 2>/dev/null; then
    log "Fork created: ${fork_slug}"
    printf '%s' "${fork_slug}"
    return 0
  fi

  # Namespace collision or eventual consistency — re-check before failing.
  sleep 2
  if fork_exists_for_user "$user" "$repo_name"; then
    log "Fork available after retry: ${fork_slug}"
    printf '%s' "${fork_slug}"
    return 0
  fi

  die "Unable to fork ${upstream}. Ensure token scopes include repo and that the upstream repository is accessible."
}

resolve_target_repo() {
  local upstream="${1:-${DEFAULT_UPSTREAM}}"
  local explicit_fork="${2:-}"

  if [[ -n "${explicit_fork}" ]]; then
    log "Using explicit target repository: ${explicit_fork}"
    printf '%s' "${explicit_fork}"
    return 0
  fi

  ensure_fork "${upstream}"
}
