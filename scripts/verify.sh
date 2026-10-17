#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
if [[ $# -ne 2 || ! "$1" =~ ^v[12]$ || ! "$2" =~ ^v[12]$ ]]; then
  echo 'Usage: ./scripts/verify.sh v1|v2 v1|v2' >&2; exit 2
fi
for spec in "staging:$1:8082:30082" "prod:$2:8081:30081"; do
  IFS=: read -r env ver port nodeport <<< "$spec"
  ns="flowbase-$env"
  desired_version="$(awk '/^  version: v[12]$/ {print $2}' "charts/flowbase-web/values-$env.yaml")"
  [[ "$desired_version" == "$ver" ]] || { echo "[FAIL] GitOps $env values expect $desired_version, not $ver" >&2; exit 1; }
  actual_port="$(kubectl -n "$ns" get svc flowbase-web -o jsonpath='{.spec.ports[0].nodePort}')"
  [[ "$actual_port" == "$nodeport" ]] || { echo "[FAIL] $env NodePort $actual_port" >&2; exit 1; }
  actual_image="$(kubectl -n "$ns" get deploy flowbase-web -o jsonpath='{.spec.template.spec.containers[0].image}')"
  [[ "$actual_image" == "flowbase-web:$ver" ]] || { echo "[FAIL] $env image is $actual_image, expected flowbase-web:$ver" >&2; exit 1; }
  pull_policy="$(kubectl -n "$ns" get deploy flowbase-web -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}')"
  [[ "$pull_policy" == Never ]] || { echo "[FAIL] $env pullPolicy=$pull_policy, expected Never" >&2; exit 1; }
  kubectl -n "$ns" rollout status deployment/flowbase-web --timeout=120s
  ok=0
  for attempt in {1..24}; do
    sync="$(kubectl -n argocd get application "flowbase-$env" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health="$(kubectl -n argocd get application "flowbase-$env" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    if [[ "$sync" == Synced && "$health" == Healthy ]] &&        curl -fsS --max-time 3 "http://localhost:$port/version.json" 2>/dev/null |        python3 -c 'import json,sys; assert json.load(sys.stdin)["version"]==sys.argv[1]' "$ver" 2>/dev/null; then
      ok=1; break
    fi
    sleep 5
  done
  [[ "$ok" == 1 ]] || { echo "[FAIL] $env: HTTP v$ver or Synced/Healthy check failed" >&2; exit 1; }
  echo "[PASS] flowbase-$env / $ver / flowbase-web:$ver / imagePullPolicy=Never / Synced Healthy / HTTP OK"
done
