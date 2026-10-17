#!/usr/bin/env bash
# Must be logged into the Argo CD CLI AS demo-developer before running this.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v argocd >/dev/null || { echo '[FAIL] argocd CLI not installed' >&2; exit 1; }
check_permission() {
  local expected="$1" action="$2" resource="$3" object="$4" actual
  actual="$(argocd account can-i "$action" "$resource" "$object")" || {
    echo '[FAIL] Unable to query Argo CD RBAC. Is ./scripts/start-ui.sh running and CLI logged in?' >&2
    return 1
  }
  actual="$(echo "$actual" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  [[ "$actual" == "$expected" ]] || {
    echo "[FAIL] ${action} ${resource} ${object}: expected ${expected}, got ${actual}. Login as demo-developer and check RBAC." >&2
    return 1
  }
  echo "[PASS] ${action} ${resource} ${object} => ${actual}"
}
check_permission yes get applications flowbase/flowbase-staging
check_permission yes sync applications flowbase/flowbase-staging
check_permission yes sync applications flowbase/flowbase-prod
check_permission no update projects flowbase
check_permission no delete applications flowbase/flowbase-prod
check_permission no sync applications default/other
printf '[PASS] Demo developer can sync only intended applications, cannot mutate projects or delete applications.\n'
