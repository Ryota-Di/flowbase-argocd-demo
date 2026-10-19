#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
command -v argocd >/dev/null || { echo '[FAIL] argocd CLI missing. Install via brew install argocd'; exit 1; }
python3 - <<'PY'
import json,subprocess,sys
items=json.loads(subprocess.check_output(['kubectl','-n','argocd','get','applications',
 '-l','flowbase.example/showcase=true','-o','json'],text=True))['items']
expected={f'flowbase-{svc}-{env}' for svc in ('auth','billing','catalog','gateway','inventory','notifications','orders','reporting','search') for env in ('prod','staging')}
actual={a['metadata']['name'] for a in items}
if actual!=expected:
 sys.exit(f'[FAIL] Refusing Sync. Selector mismatch: missing={sorted(expected-actual)} extra={sorted(actual-expected)}')
for a in items:
 if 'automated' in a['spec'].get('syncPolicy',{}): sys.exit('[FAIL] Unexpected automated sync: '+a['metadata']['name'])
print('[PASS] Sync selector resolves to exactly 18 mock applications; two Checkout Apps excluded')
PY
argocd account get-user-info >/dev/null || { echo '[FAIL] Argo CD CLI not logged in; run argocd login localhost:8080 --username admin --insecure'; exit 1; }
argocd app sync -l 'flowbase.example/showcase=true' --timeout 240
./scripts/check-showcase.sh
