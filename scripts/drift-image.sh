#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
kubectl -n flowbase-prod set image deployment/flowbase-web nginx=nginx:flowbase-invalid-demo-tag
printf 'Production image drift injected (demo only). UI: Refresh -> Deployment Diff -> manual Sync.\n'
