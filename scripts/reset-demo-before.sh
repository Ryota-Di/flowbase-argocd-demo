#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
[[ "${1:-}" == '--confirm-local-demo' ]] || { echo '[FAIL] Usage: ./scripts/reset-demo-before.sh --confirm-local-demo'; exit 2; }
if ./scripts/demo-state.sh before >/dev/null 2>&1; then
 echo '[PASS] Demo already in BEFORE state'; exit 0
fi
if ./scripts/demo-state.sh after-a >/dev/null 2>&1; then
 mode=after-a
elif ./scripts/demo-state.sh after-b >/dev/null 2>&1; then
 mode=after-b
else
 echo '[FAIL] Unknown live state, refusing blind reset. Check scripts/demo-state.sh and Deployment manually.' >&2
 exit 1
fi
if ! docker exec argocd-demo-control-plane crictl images | grep -Eq '^docker.io/library/flowbase-web[[:space:]]+v1[[:space:]]'; then
 echo '[FAIL] v1 image not found inside kind control-plane node; refusing reset' >&2
 exit 1
fi
# Strategic merge patches exactly three managed fields. Never change Git or App sync policy.
kubectl -n flowbase-prod patch deployment flowbase-web --type=strategic --patch \
 '{"spec":{"replicas":1,"template":{"metadata":{"annotations":{"flowbase.example/release":"v1"}},"spec":{"containers":[{"name":"web","image":"flowbase-web:v1"}]}}}}'
kubectl -n flowbase-prod rollout status deployment/flowbase-web --timeout=120s
printf '[PASS] Reset %s: live image=v1, replicas=1, release annotation=v1. Git remains v2.\n' "$mode"
printf '[NEXT] ./scripts/refresh-prod.sh ; ./scripts/demo-state.sh before\n'
