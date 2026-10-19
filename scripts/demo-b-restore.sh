#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
[[ "${1:-}" == '--confirm-local-demo' ]] || { echo '[FAIL] Usage: ./scripts/demo-b-restore.sh --confirm-local-demo'; exit 2; }
./scripts/demo-state.sh after-b
kubectl -n flowbase-prod scale deployment/flowbase-web --current-replicas=2 --replicas=1
kubectl -n flowbase-prod rollout status deployment/flowbase-web --timeout=120s
printf '[PASS] Drift removed, Production live=v2; Refresh application (or ./scripts/refresh-prod.sh) and verify after-a.\n'
