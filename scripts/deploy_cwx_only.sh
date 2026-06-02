#!/usr/bin/env bash
set -euo pipefail

# Deploy only 3 CWX files from Git repo to a live TF directory.
# Safe defaults:
# - sparse checkout only these files
# - backup current live files before overwrite
# - optional fixed ref checkout
#
# Usage:
#   ./scripts/deploy_cwx_only.sh \
#     --repo-url git@github.com:ORG/REPO.git \
#     --live-tf /srv/tf/tf \
#     [--branch master] \
#     [--ref <commit-or-tag>] \
#     [--keep-tmp]

REPO_URL=""
LIVE_TF=""
BRANCH="master"
REF=""
KEEP_TMP="0"

usage() {
  cat <<'EOF'
Usage:
  deploy_cwx_only.sh --repo-url <url> --live-tf <dir> [--branch <name>] [--ref <commit-or-tag>] [--keep-tmp]

Options:
  --repo-url   Git repository URL.
  --live-tf    Live TF root directory (contains addons/...).
  --branch     Branch to checkout (default: master).
  --ref        Optional fixed commit/tag. If set, overrides branch tip.
  --keep-tmp   Keep temporary working directory for debugging.
  -h, --help   Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-url) REPO_URL="$2"; shift 2 ;;
    --live-tf) LIVE_TF="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
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

for p in git install cp mkdir; do
  command -v "$p" >/dev/null 2>&1 || { echo "Missing command: $p" >&2; exit 127; }
done

if [[ ! -d "$LIVE_TF" ]]; then
  echo "Live TF directory does not exist: $LIVE_TF" >&2
  exit 1
fi

CWX_DIR="$LIVE_TF/addons/sourcemod/configs/cwx"
mkdir -p "$CWX_DIR"

TMP_DIR="$(mktemp -d -t cwx-deploy-XXXXXXXX)"
cleanup() {
  if [[ "$KEEP_TMP" == "0" ]]; then
    rm -rf "$TMP_DIR"
  else
    echo "Keeping temp dir: $TMP_DIR"
  fi
}
trap cleanup EXIT

echo "[1/6] Clone repository (no checkout)"
git clone --filter=blob:none --no-checkout "$REPO_URL" "$TMP_DIR/repo"

cd "$TMP_DIR/repo"

echo "[2/6] Sparse checkout only 3 CWX files"
git sparse-checkout init --no-cone
git sparse-checkout set \
  tf/addons/sourcemod/configs/cwx/example_items.txt \
  tf/addons/sourcemod/configs/cwx/hellbomb.txt \
  tf/addons/sourcemod/configs/cwx/ww2.txt

if [[ -n "$REF" ]]; then
  echo "[3/6] Checkout fixed ref: $REF"
  git checkout "$REF"
else
  echo "[3/6] Checkout branch: $BRANCH"
  git checkout "$BRANCH"
fi

DEPLOYED_REF="$(git rev-parse --short HEAD)"
echo "Resolved commit: $DEPLOYED_REF"

BACKUP_DIR="$LIVE_TF/backup/cwx-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "[4/6] Backup current live files"
for f in example_items.txt hellbomb.txt ww2.txt; do
  if [[ -f "$CWX_DIR/$f" ]]; then
    cp -a "$CWX_DIR/$f" "$BACKUP_DIR/$f"
  fi
done

echo "[5/6] Install new files"
install -m 644 tf/addons/sourcemod/configs/cwx/example_items.txt "$CWX_DIR/example_items.txt"
install -m 644 tf/addons/sourcemod/configs/cwx/hellbomb.txt "$CWX_DIR/hellbomb.txt"
install -m 644 tf/addons/sourcemod/configs/cwx/ww2.txt "$CWX_DIR/ww2.txt"

echo "[6/6] Done"
echo "Backup dir: $BACKUP_DIR"
echo "Deployed commit: $DEPLOYED_REF"
