#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
kubectl -n argocd get svc argocd-server >/dev/null
printf 'Argo CD UI: https://localhost:8080 (keep this terminal open; Ctrl+C to stop)\n'
exec kubectl -n argocd port-forward --address 127.0.0.1 svc/argocd-server 8080:443
