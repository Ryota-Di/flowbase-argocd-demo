#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
case "${1:-}" in
  cluster) check_context; kubectl get nodes; kubectl wait --for=condition=Ready nodes --all --timeout=15s;;
  argocd) check_context; kubectl -n argocd get deployments argocd-server argocd-repo-server;;
  apps) check_context; kubectl -n argocd get appproject flowbase; kubectl -n argocd get applications flowbase-staging flowbase-prod;;
  v1|v2) exec ./scripts/verify.sh "$@";;
  *) echo 'Usage: ./scripts/check.sh cluster|argocd|apps|v1 v1|v2 v1|v2 v2' >&2; exit 2;;
esac
