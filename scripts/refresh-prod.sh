#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
kubectl -n argocd annotate application flowbase-prod argocd.argoproj.io/refresh=normal --overwrite >/dev/null
printf '[PASS] Requested status refresh only (no Sync). Check Argo CD UI status/Diff.\n'
