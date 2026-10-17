#!/usr/bin/env bash
# Installs ONLY into kind-argocd-demo; safe to rerun. Never deletes clusters.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh

fail() { echo "[FAIL] $*" >&2; exit 1; }
log() { printf '\n[SETUP] %s\n' "$*"; }

log '1/5 Dependencies and Docker'
for program in docker kind kubectl helm argocd git python3 curl; do
  command -v "$program" >/dev/null || fail "Missing $program. On Mac run: brew install kind kubectl helm argocd gh python git (Docker Desktop is separate)."
done
docker info >/dev/null 2>&1 || fail 'Start Docker Desktop, then rerun.'

log '2/5 Offline configuration tests'
./scripts/local-tests.sh

log '3/5 kind cluster (will NOT delete existing clusters)'
if kind get clusters | grep -Fxq 'argocd-demo'; then
  echo '[SKIP] Cluster already exists; validating its network mappings.'
else
  for port in 8081 8082; do
    if command -v lsof >/dev/null && lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | grep -q .; then
      fail "TCP $port is already in use. Close the conflicting program; don't delete an existing cluster blindly."
    fi
  done
  kind create cluster --name argocd-demo --config kind-config.yaml --wait 5m
fi
check_context
kubectl wait --for=condition=Ready nodes --all --timeout=180s
./scripts/check.sh cluster

log '4/5 Argo CD install (skips already installed server/repo-server)'
if kubectl -n argocd get deployment argocd-server argocd-repo-server >/dev/null 2>&1 \
    && kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
  echo '[SKIP] Argo CD deployments already exist. Not upgrading their version.'
else
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  ARGOCD_INSTALL_REF="${ARGOCD_INSTALL_REF:-stable}"
  [[ "$ARGOCD_INSTALL_REF" =~ ^(stable|v[0-9]+\.[0-9]+\.[0-9]+)$ ]] || fail 'ARGOCD_INSTALL_REF must be stable or vX.Y.Z'
  kubectl apply -n argocd --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_INSTALL_REF}/manifests/install.yaml"
fi
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=120s
./scripts/check.sh argocd

log '5/5 Next step'
echo 'PASS: infrastructure is ready.'
echo 'Next: create an EMPTY PUBLIC GitHub repo (no README) then run:'
echo '  ./scripts/connect-github.sh https://github.com/YOUR_USERNAME/flowbase-argocd-demo.git'
echo 'Then in another terminal: ./scripts/start-ui.sh'
