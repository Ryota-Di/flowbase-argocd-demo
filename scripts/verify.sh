#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
if [[ $# -ne 2 || ! "$1" =~ ^v[12]$ || ! "$2" =~ ^v[12]$ ]]; then
  echo 'Usage: ./scripts/verify.sh v1|v2 v1|v2  (staging-version production-version)' >&2
  exit 1
fi
check_context
# Sync/Health reporting is eventually consistent; wait rather than failing immediately.
wait_for_argocd() {
  local app="$1" deadline=$((SECONDS + 180)) sync health
  while (( SECONDS < deadline )); do
    sync="$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health="$(kubectl -n argocd get application "$app" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    if [[ "$sync" == Synced && "$health" == Healthy ]]; then
      echo "[PASS] $app: Synced / Healthy"
      return 0
    fi
    printf '[WAIT] %s: %s / %s\n' "$app" "${sync:-Unknown}" "${health:-Unknown}"
    sleep 5
  done
  echo "[FAIL] $app did not become Synced/Healthy (last: $sync / $health). Open UI to inspect Diff/Events." >&2
  return 1
}
wait_for_html() {
  local url="$1" ver="$2" mode="$3" deadline=$((SECONDS + 90)) html
  while (( SECONDS < deadline )); do
    html="$(curl --connect-timeout 2 --max-time 5 -fsS "$url" 2>/dev/null || true)"
    if [[ "$html" == *"data-version=\"${ver}.0\""* && "$html" == *"data-mode=\"${mode}\""* ]]; then
      echo "[PASS] $url: ${ver}.0 / ${mode}"
      return 0
    fi
    echo "[WAIT] $url is not serving expected ${ver}.0 / ${mode} yet"
    sleep 3
  done
  echo "[FAIL] $url still does not have expected version; check NodePort, Pod and Git values." >&2
  return 1
}
for item in "flowbase-staging:$1:8082:30082" "flowbase-prod:$2:8081:30081"; do
  IFS=: read -r ns ver hostport nodeport <<< "$item"
  echo "== $ns / $ver =="
  actual_port="$(kubectl -n "$ns" get service flowbase-web -o jsonpath='{.spec.ports[0].nodePort}')"
  [[ "$actual_port" == "$nodeport" ]] || { echo "[FAIL] NodePort is $actual_port, expected $nodeport" >&2; exit 1; }
  kubectl -n "$ns" rollout status deployment/flowbase-web --timeout=120s
  image="$(kubectl -n "$ns" get deployment flowbase-web -o jsonpath='{.spec.template.spec.containers[0].image}')"
  replicas="$(kubectl -n "$ns" get deployment flowbase-web -o jsonpath='{.spec.replicas}')"
  [[ "$image" == 'nginx:stable-alpine' && "$replicas" == 1 ]] || {
    echo "[FAIL] $ns still has image=$image replicas=$replicas (expected nginx:stable-alpine / 1)" >&2
    exit 1
  }
  wait_for_argocd "$ns"
  if [[ "$ver" == v1 ]]; then mode='multi-step'; else mode='one-click'; fi
  wait_for_html "http://localhost:$hostport" "$ver" "$mode"
done
echo '[PASS] Both environments, rollout, GitOps states, image/replicas and live HTTP versions verified.'
