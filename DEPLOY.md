# Safe deploy and sync workflow

This repository has two independent operations:

1. Deploy only 3 CWX files from repo to live server.
2. Sync other live server config changes back to repo.

Keeping these operations separate avoids accidental overwrite of newer server-side configs.

## Files included in CWX-only deploy

- `tf/addons/sourcemod/configs/cwx/example_items.txt`
- `tf/addons/sourcemod/configs/cwx/hellbomb.txt`
- `tf/addons/sourcemod/configs/cwx/ww2.txt`

## 1) Deploy only CWX 3 files

```bash
chmod +x scripts/deploy_cwx_only.sh

./scripts/deploy_cwx_only.sh \
  --repo-url <REPO_URL> \
  --live-tf <LIVE_TF_DIR> \
  --branch master
```

For reproducible release, use fixed commit or tag:

```bash
./scripts/deploy_cwx_only.sh \
  --repo-url <REPO_URL> \
  --live-tf <LIVE_TF_DIR> \
  --ref <COMMIT_OR_TAG>
```

## 2) Sync server-side updates back to repo

This excludes the 3 CWX files above to avoid overwriting your CWX source of truth.

```bash
chmod +x scripts/sync_server_configs.sh

./scripts/sync_server_configs.sh \
  --repo-url <REPO_URL> \
  --live-tf <LIVE_TF_DIR> \
  --base-branch master
```

Push automatically only when ready:

```bash
./scripts/sync_server_configs.sh \
  --repo-url <REPO_URL> \
  --live-tf <LIVE_TF_DIR> \
  --base-branch master \
  --push
```

## Branch strategy

- `master`: stable baseline.
- `deploy/cwx-only` (optional): CWX-only changes.
- `sync/server-config-*`: server sync branches, review via PR before merge.

## Why not copy only .git

Avoid deploying by copying only `.git`. It is easy to accidentally run full-tree checkout/reset and overwrite files. A temporary sparse checkout + targeted copy is safer.
