#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
kubectl -n flowbase-prod scale deployment/flowbase-web --replicas=3
printf 'Production replica drift injected (demo only). UI: Refresh -> Diff -> manual Sync.\n'
