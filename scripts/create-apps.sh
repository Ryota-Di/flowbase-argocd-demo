#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
if [[ $# -ne 1 ]]; then
  echo 'Usage: ./scripts/create-apps.sh https://github.com/USERNAME/flowbase-argocd-demo.git' >&2
  exit 1
fi
REPO_URL="$1"
[[ "$REPO_URL" =~ ^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+\.git$ ]] || {
  echo 'For this demo use a public GitHub HTTPS .git URL (no URL query or credentials).' >&2; exit 1;
}
check_context
kubectl -n argocd get deployment argocd-server >/dev/null
# Bootstrap is an admin task. Namespace creation is intentionally outside Argo CD.
for ns in flowbase-staging flowbase-prod; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
cat <<YAML | kubectl -n argocd apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: flowbase
  namespace: argocd
spec:
  description: FlowBase demo — only this repository and these two namespaces
  sourceRepos:
    - ${REPO_URL}
  destinations:
    - server: https://kubernetes.default.svc
      namespace: flowbase-staging
    - server: https://kubernetes.default.svc
      namespace: flowbase-prod
  namespaceResourceWhitelist:
    - {group: "", kind: ConfigMap}
    - {group: "", kind: Service}
    - {group: apps, kind: Deployment}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flowbase-staging
  namespace: argocd
spec:
  project: flowbase
  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: charts/flowbase-web
    helm:
      valueFiles:
        - values-staging.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: flowbase-staging
  syncPolicy: {}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flowbase-prod
  namespace: argocd
spec:
  project: flowbase
  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: charts/flowbase-web
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: flowbase-prod
  syncPolicy: {}
YAML
printf '\nCreated restricted AppProject + staging/prod Applications. Manual Sync is required.\n'
