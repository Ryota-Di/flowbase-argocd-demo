#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
if [[ $# -eq 0 ]]; then
  exec ./scripts/prepare-pr.sh reset
fi
if [[ $# -ne 1 || "$1" != '--direct-demo-only' ]]; then
  echo 'Usage: ./scripts/reset-v1.sh [--direct-demo-only]' >&2
  exit 1
fi
require_main_clean
[[ "$(git remote get-url origin)" == *'flowbase-argocd-demo'* ]] || {
  echo 'Refusing direct demo reset: origin URL does not look like the demo repository.' >&2; exit 1;
}
cp scenarios/values-staging-v1.yaml charts/flowbase-web/values-staging.yaml
cp scenarios/values-prod-v1.yaml charts/flowbase-web/values-prod.yaml
git add charts/flowbase-web/values-staging.yaml charts/flowbase-web/values-prod.yaml
if git diff --cached --quiet; then
  echo 'Both environment Git values are already v1.'
else
  git commit -m 'demo-only: reset staging and production to v1'
  git push origin main
fi
cat <<'MSG'
Demo-only bypass completed, NOT an acceptable normal release process.
Argo CD UI: Refresh and manual-Sync BOTH apps, then run ./scripts/verify.sh v1 v1.
Note: branch protection may disallow direct reset; in that case use the default reset PR.
MSG
