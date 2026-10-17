#!/usr/bin/env bash
# Phase-specific diagnosis. No cluster changes or synchronization are performed.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }
phase="${1:-}"
case "$phase" in
  tools)
    for bin in docker kind kubectl helm argocd git python3 curl; do
      command -v "$bin" >/dev/null || fail "Missing '$bin' (install dependencies)."
    done
    docker info >/dev/null 2>&1 || fail 'Docker Desktop is not running.'
    pass 'required local tools and Docker'
    ;;
  cluster)
    check_context
    kubectl cluster-info >/dev/null || fail 'Kubernetes API is unreachable.'
    kubectl get nodes -o wide
    kubectl wait --for=condition=Ready nodes --all --timeout=10s >/dev/null || fail 'A kind node is not Ready.'
    node='argocd-demo-control-plane'
    for item in '30081:8081' '30082:8082'; do
      IFS=: read -r inner outer <<< "$item"
      mapping="$(docker port "$node" "$inner/tcp" 2>/dev/null)" || fail "Missing container port $inner; recreate the demo cluster with kind-config.yaml after explicit confirmation."
      [[ "$mapping" == *":$outer"* ]] || fail "Expected host port $outer for node port $inner, found: $mapping"
      echo "[OK] node:$inner => localhost:$outer ($mapping)"
    done
    pass 'kind context, ready node, port mappings'
    ;;
  argocd)
    check_context
    kubectl -n argocd get deployment argocd-server argocd-repo-server
    kubectl -n argocd rollout status deployment/argocd-server --timeout=10s >/dev/null || fail 'argocd-server is not Ready'
    kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=10s >/dev/null || fail 'argocd-repo-server is not Ready'
    kubectl get crd applications.argoproj.io >/dev/null || fail 'Argo CD Application CRD missing'
    pass 'Argo CD server, repo server, Application CRD'
    ;;
  apps)
    check_context
    kubectl -n argocd get appproject flowbase >/dev/null || fail 'AppProject flowbase not found.'
    kubectl -n argocd get applications flowbase-staging flowbase-prod -o wide || fail 'Missing Applications.'
    kubectl get namespace flowbase-staging flowbase-prod >/dev/null || fail 'Demo namespaces missing.'
    pass 'Application definitions are registered (first Sync may still be needed)'
    ;;
  v1|v2)
    [[ $# -eq 2 && "$2" =~ ^v[12]$ ]] || fail 'Usage: ./scripts/check.sh v1|v2 v1|v2 (staging-version prod-version)'
    exec ./scripts/verify.sh "$1" "$2"
    ;;
  *)
    cat <<'USAGE' >&2
Usage:
  ./scripts/check.sh tools          # Before installing
  ./scripts/check.sh cluster        # After creating kind cluster
  ./scripts/check.sh argocd         # After installing Argo CD
  ./scripts/check.sh apps           # After registering applications, BEFORE first Sync
  ./scripts/check.sh v1 v1          # After initial Sync
  ./scripts/check.sh v2 v1          # After staging Sync
  ./scripts/check.sh v2 v2          # After prod Sync / drift recovery
USAGE
    exit 2
    ;;
esac
