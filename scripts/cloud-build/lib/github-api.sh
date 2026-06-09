#!/usr/bin/env bash
# Push workflow manifest to a remote repository via GitHub Contents REST API.

if [[ -n "${CLOUD_BUILD_GITHUB_API_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
CLOUD_BUILD_GITHUB_API_LOADED=1

set -euo pipefail

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

get_remote_file_sha() {
  local owner="$1"
  local repo="$2"
  local path="$3"
  local branch="$4"
  local sha=""

  sha="$(gh api "repos/${owner}/${repo}/contents/${path}?ref=${branch}" --jq .sha 2>/dev/null || true)"
  if [[ "${sha}" =~ ^[a-f0-9]{40}$ ]]; then
    printf '%s' "${sha}"
  fi
}

inject_workflow_via_api() {
  local repo_slug="$1"
  local branch="${2:-${DEFAULT_BRANCH}}"
  local local_file="${3:-${WORKFLOW_TEMPLATE}}"
  local remote_path="${4:-${WORKFLOW_REMOTE_PATH}}"
  local message="${5:-chore(ci): inject headless unsigned IPA build workflow}"

  local owner repo_name content_b64 sha

  owner="$(repo_owner "$repo_slug")"
  repo_name="$(repo_name "$repo_slug")"
  [[ -f "${local_file}" ]] || die "Workflow template not found: ${local_file}"

  content_b64="$(base64_encode_file "${local_file}")"
  sha="$(get_remote_file_sha "${owner}" "${repo_name}" "${remote_path}" "${branch}")"

  log "Uploading workflow via Contents API: ${repo_slug}:${remote_path} (branch=${branch})"

  local -a api_args=(
    --method PUT
    "repos/${owner}/${repo_name}/contents/${remote_path}"
    -f message="${message}"
    -f content="${content_b64}"
    -f branch="${branch}"
  )

  if [[ -n "${sha}" ]]; then
    api_args+=(-f sha="${sha}")
    log "Updating existing workflow (sha=${sha:0:12}...)"
  else
    log "Creating new workflow file"
  fi

  gh api "${api_args[@]}" --jq '{commit: .commit.sha, content: .content.path}'
}

print_workflow_base64_stream() {
  local local_file="${1:-${WORKFLOW_TEMPLATE}}"
  [[ -f "${local_file}" ]] || die "Workflow template not found: ${local_file}"
  base64_encode_file "${local_file}"
}
