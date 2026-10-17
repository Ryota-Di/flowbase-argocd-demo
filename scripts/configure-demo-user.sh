#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
kubectl -n argocd get configmap argocd-cm argocd-rbac-cm >/dev/null
# A local UI account without API-key capability. Intentionally no privileges by default.
kubectl -n argocd patch configmap argocd-cm --type merge \
  -p '{"data":{"accounts.demo-developer":"login"}}'
kubectl -n argocd patch configmap argocd-rbac-cm --type merge \
  -p '{"data":{"policy.default":"role:authenticated","policy.csv":"p, role:flowbase-deployer, applications, get, flowbase/flowbase-staging, allow\np, role:flowbase-deployer, applications, get, flowbase/flowbase-prod, allow\np, role:flowbase-deployer, applications, sync, flowbase/flowbase-staging, allow\np, role:flowbase-deployer, applications, sync, flowbase/flowbase-prod, allow\np, role:flowbase-deployer, projects, get, flowbase, allow\ng, demo-developer, role:flowbase-deployer"}}'
cat <<'MSG'
Configured demo-developer RBAC: can view + manual-Sync flowbase apps only.
Next (after GUI port-forward is active):
  1. brew install argocd
  2. argocd login localhost:8080 --username admin --insecure
  3. argocd account update-password --account demo-developer
     (interactive: enter CURRENT admin password then the NEW demo-developer password)
  4. Sign out of the GUI admin session; log in as demo-developer.
Do not store passwords in Git or pass them as command-line arguments.
This local user is demonstration-only; use SSO and stronger governance in production.
MSG
