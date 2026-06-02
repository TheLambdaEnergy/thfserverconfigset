#!/usr/bin/env bash
set -euo pipefail

# Export live server TF configs (except 3 CWX files), apply to a repo worktree,
# and commit on a new branch for review.
#
# Safe defaults:
# - does NOT auto-push unless --push is provided
# - excludes the 3 CWX files to avoid overwriting cwx-only deployment source
#
# Usage:
#   ./scripts/sync_server_configs.sh \
#     --repo-url git@github.com:ORG/REPO.git \
#     --live-tf /srv/tf/tf \
#     [--base-branch master] \
#     [--branch-name sync/server-config-20260602] \
#     [--push]

REPO_URL=""
LIVE_TF=""
BASE_BRANCH="master"
BRANCH_NAME=""
DO_PUSH="0"
KEEP_TMP="0"

usage() {
  cat <<'EOF'
Usage:
  sync_server_configs.sh --repo-url <url> --live-tf <dir> [--base-branch <name>] [--branch-name <name>] [--push] [--keep-tmp]

Options:
  --repo-url      Git repository URL.
  --live-tf       Live TF root directory (contains addons/...).
  --base-branch   Branch to branch off from (default: master).
  --branch-name   Sync branch name. Default auto-generated.
  --push          Push the branch to origin.
  --keep-tmp      Keep temporary working directory for debugging.
  -h, --help      Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-url) REPO_URL="$2"; shift 2 ;;
    --live-tf) LIVE_TF="$2"; shift 2 ;;
    --base-branch) BASE_BRANCH="$2"; shift 2 ;;
    --branch-name) BRANCH_NAME="$2"; shift 2 ;;
    --push) DO_PUSH="1"; shift ;;
    --keep-tmp) KEEP_TMP="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$REPO_URL" || -z "$LIVE_TF" ]]; then
  echo "--repo-url and --live-tf are required." >&2
  usage
  exit 2
fi

if [[ -z "$BRANCH_NAME" ]]; then
  BRANCH_NAME="sync/server-config-$(date +%Y%m%d-%H%M%S)"
fi

for p in git rsync mkdir; do
  command -v "$p" >/dev/null 2>&1 || { echo "Missing command: $p" >&2; exit 127; }
done

if [[ ! -d "$LIVE_TF" ]]; then
  echo "Live TF directory does not exist: $LIVE_TF" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d -t tf-sync-XXXXXXXX)"
cleanup() {
  if [[ "$KEEP_TMP" == "0" ]]; then
    rm -rf "$TMP_DIR"
  else
    echo "Keeping temp dir: $TMP_DIR"
  fi
}
trap cleanup EXIT

EXPORT_DIR="$TMP_DIR/export"
WORK_DIR="$TMP_DIR/repo"
mkdir -p "$EXPORT_DIR"

echo "[1/6] Export live TF tree (excluding 3 CWX files)"
rsync -a \
  --exclude 'addons/sourcemod/configs/cwx/example_items.txt' \
  --exclude 'addons/sourcemod/configs/cwx/hellbomb.txt' \
  --exclude 'addons/sourcemod/configs/cwx/ww2.txt' \
  "$LIVE_TF/" "$EXPORT_DIR/"

echo "[2/6] Clone repository"
git clone "$REPO_URL" "$WORK_DIR"
cd "$WORK_DIR"

echo "[3/6] Create sync branch from $BASE_BRANCH"
git checkout "$BASE_BRANCH"
git checkout -b "$BRANCH_NAME"

echo "[4/6] Apply exported files to repo path: tf/"
mkdir -p "$WORK_DIR/tf"
rsync -a --delete "$EXPORT_DIR/" "$WORK_DIR/tf/"

echo "[5/6] Create commit if there are changes"
if git diff --quiet && git diff --cached --quiet; then
  echo "No changes detected. Nothing to commit."
  exit 0
fi

git add -A
if git diff --cached --quiet; then
  echo "No staged changes. Nothing to commit."
  exit 0
fi

git commit -m "sync: server-side config updates (exclude cwx 3 files)"

echo "[6/6] Done"
echo "Branch: $BRANCH_NAME"

if [[ "$DO_PUSH" == "1" ]]; then
  git push -u origin "$BRANCH_NAME"
  echo "Pushed to origin/$BRANCH_NAME"
else
  echo "Not pushed by default. Review and push manually if needed:"
  echo "  git -C '$WORK_DIR' push -u origin '$BRANCH_NAME'"
fi
