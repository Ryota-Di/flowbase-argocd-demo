#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
[[ "${1:-}" == '--confirm-local-demo' ]] || { echo '[FAIL] Usage: ./scripts/demo-b-create-drift.sh --confirm-local-demo'; exit 2; }
./scripts/demo-state.sh after-a
kubectl -n flowbase-prod scale deployment/flowbase-web --current-replicas=1 --replicas=2
kubectl -n flowbase-prod rollout status deployment/flowbase-web --timeout=120s
printf '[DEMO B] Production Git replicas=1 vs live replicas=2; refresh Argo CD (no Sync).\n'
