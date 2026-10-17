#!/usr/bin/env bash
# Demonstrate a reversible, low-risk configuration drift in the local cluster.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
[[ "${1:-}" == '--demo-only' ]] || { echo 'Usage: ./scripts/drift-replicas.sh --demo-only' >&2; exit 2; }
kubectl -n flowbase-staging scale deployment/flowbase-web --replicas=2
echo '[DEMO] Staging replicas changed from Git desired=1 to live=2. Argo CD Refresh -> Diff -> manual Sync to reconcile.'
