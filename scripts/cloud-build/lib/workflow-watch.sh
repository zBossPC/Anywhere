#!/usr/bin/env bash
# Dispatch workflow, watch execution, and download build artifacts.

if [[ -n "${CLOUD_BUILD_WORKFLOW_WATCH_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
CLOUD_BUILD_WORKFLOW_WATCH_LOADED=1

set -euo pipefail

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

dispatch_workflow() {
  local repo_slug="$1"
  local branch="${2:-${DEFAULT_BRANCH}}"
  local workflow_file="${3:-build.yml}"

  log "Dispatching workflow_dispatch: ${repo_slug}/${workflow_file} (ref=${branch})"
  gh workflow run "${workflow_file}" --repo "${repo_slug}" --ref "${branch}"
}

wait_for_latest_run_id() {
  local repo_slug="$1"
  local workflow_file="${2:-build.yml}"
  local attempts="${3:-30}"
  local sleep_secs="${4:-5}"
  local run_id=""

  for ((i = 1; i <= attempts; i++)); do
    run_id="$(gh run list \
      --repo "${repo_slug}" \
      --workflow "${workflow_file}" \
      --limit 1 \
      --json databaseId,status,conclusion \
      --jq '.[0].databaseId // empty' 2>/dev/null || true)"

    if [[ -n "${run_id}" ]]; then
      printf '%s' "${run_id}"
      return 0
    fi

    sleep "${sleep_secs}"
  done

  die "Timed out waiting for workflow run to appear for ${repo_slug}/${workflow_file}"
}

watch_workflow_run() {
  local repo_slug="$1"
  local run_id="$2"

  log "Watching run ${run_id} on ${repo_slug}..."
  gh run watch "${run_id}" --repo "${repo_slug}" --exit-status
}

assert_run_success() {
  local repo_slug="$1"
  local run_id="$2"
  local conclusion

  conclusion="$(gh run view "${run_id}" --repo "${repo_slug}" --json conclusion --jq .conclusion)"
  if [[ "${conclusion}" != "success" ]]; then
    die "Workflow run ${run_id} finished with conclusion=${conclusion:-unknown}"
  fi
  log "Workflow run ${run_id} succeeded"
}

download_unsigned_ipa() {
  local repo_slug="$1"
  local run_id="$2"
  local dest_dir="${3:-${WORKSPACE_ROOT}}"

  mkdir -p "${dest_dir}"
  log "Downloading artifact '${ARTIFACT_NAME}' to ${dest_dir}"
  gh run download "${run_id}" \
    --repo "${repo_slug}" \
    --name "${ARTIFACT_NAME}" \
    --dir "${dest_dir}"

  if [[ -f "${dest_dir}/Anywhere.ipa" ]]; then
    log "Artifact ready: ${dest_dir}/Anywhere.ipa"
    ls -lh "${dest_dir}/Anywhere.ipa"
  else
    find "${dest_dir}" -maxdepth 2 -name '*.ipa' -print
  fi
}
