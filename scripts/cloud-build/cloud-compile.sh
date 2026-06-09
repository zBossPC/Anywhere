#!/usr/bin/env bash
#
# Headless remote cloud-compilation loop for NodePassProject/Anywhere.
#
# Usage:
#   ./scripts/cloud-build/cloud-compile.sh
#   ./scripts/cloud-build/cloud-compile.sh --dry-run
#   ./scripts/cloud-build/cloud-compile.sh --fork zBossPC/Anywhere --branch main
#   ./scripts/cloud-build/cloud-compile.sh --print-base64
#
# Examples:
#   ./scripts/cloud-build/cloud-compile.sh --dry-run
#   ./scripts/cloud-build/cloud-compile.sh --fork "$(gh api user -q .login)/Anywhere"
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/gh-auth.sh
source "${SCRIPT_DIR}/lib/gh-auth.sh"
# shellcheck source=lib/fork.sh
source "${SCRIPT_DIR}/lib/fork.sh"
# shellcheck source=lib/github-api.sh
source "${SCRIPT_DIR}/lib/github-api.sh"
# shellcheck source=lib/workflow-watch.sh
source "${SCRIPT_DIR}/lib/workflow-watch.sh"

UPSTREAM="${DEFAULT_UPSTREAM}"
TARGET_REPO=""
BRANCH="${DEFAULT_BRANCH}"
WORKFLOW_FILE="build.yml"
DEST_DIR="${WORKSPACE_ROOT}"
DRY_RUN=0
PRINT_BASE64=0
SKIP_DOWNLOAD=0
SKIP_DISPATCH=0

usage() {
  cat <<'EOF'
Headless cloud compilation for Anywhere (unsigned IPA via GitHub Actions).

Options:
  --upstream <owner/repo>   Upstream source (default: NodePassProject/Anywhere)
  --fork <owner/repo>       Target fork (skip auto-fork; use existing remote repo)
  --branch <name>           Git branch for workflow injection (default: main)
  --dest <path>             Artifact download directory (default: workspace root)
  --dry-run                 Validate auth and print planned actions only
  --print-base64            Emit Base64 workflow payload and exit
  --skip-dispatch           Inject workflow only; do not dispatch or download
  --skip-download           Dispatch and watch; do not download artifact
  -h, --help                Show this help

Examples:
  ./scripts/cloud-build/cloud-compile.sh --dry-run
  ./scripts/cloud-build/cloud-compile.sh --fork zBossPC/Anywhere
  ./scripts/cloud-build/cloud-compile.sh --print-base64 | head -c 80
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upstream)
      UPSTREAM="$2"
      shift 2
      ;;
    --fork)
      TARGET_REPO="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --dest)
      DEST_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --print-base64)
      PRINT_BASE64=1
      shift
      ;;
    --skip-dispatch)
      SKIP_DISPATCH=1
      shift
      ;;
    --skip-download)
      SKIP_DOWNLOAD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1 (try --help)"
      ;;
  esac
done

if [[ "${PRINT_BASE64}" -eq 1 ]]; then
  print_workflow_base64_stream "${WORKFLOW_TEMPLATE}"
  exit 0
fi

main() {
  ensure_gh_auth
  local repo_slug
  repo_slug="$(resolve_target_repo "${UPSTREAM}" "${TARGET_REPO}")"

  log "Upstream: ${UPSTREAM}"
  log "Target repository: ${repo_slug}"
  log "Workflow branch: ${BRANCH}"
  log "Workflow template: ${WORKFLOW_TEMPLATE}"
  log "Artifact name: ${ARTIFACT_NAME}"

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "DRY RUN — planned actions:"
    log "  1. PUT ${WORKFLOW_REMOTE_PATH} -> ${repo_slug}@${BRANCH} (Base64 via Contents API)"
    log "  2. gh workflow run ${WORKFLOW_FILE} --repo ${repo_slug} --ref ${BRANCH}"
    log "  3. gh run watch <run_id> --repo ${repo_slug}"
    log "  4. gh run download <run_id> -n ${ARTIFACT_NAME} --dir ${DEST_DIR}"
    exit 0
  fi

  inject_workflow_via_api "${repo_slug}" "${BRANCH}"

  if [[ "${SKIP_DISPATCH}" -eq 1 ]]; then
    log "Skipping workflow dispatch (--skip-dispatch)"
    exit 0
  fi

  dispatch_workflow "${repo_slug}" "${BRANCH}" "${WORKFLOW_FILE}"
  local run_id
  run_id="$(wait_for_latest_run_id "${repo_slug}" "${WORKFLOW_FILE}")"
  log "Run ID: ${run_id}"

  watch_workflow_run "${repo_slug}" "${run_id}"
  assert_run_success "${repo_slug}" "${run_id}"

  if [[ "${SKIP_DOWNLOAD}" -eq 1 ]]; then
    log "Skipping artifact download (--skip-download)"
    exit 0
  fi

  download_unsigned_ipa "${repo_slug}" "${run_id}" "${DEST_DIR}"
  log "Cloud compile loop complete."
}

main "$@"
