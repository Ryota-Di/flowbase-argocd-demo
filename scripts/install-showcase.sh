#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
require_main_clean
[[ -f showcase/applications.yaml ]] || { echo '[FAIL] No showcase/applications.yaml'; exit 1; }
python3 - <<'PY'
import json,subprocess,sys
raw=subprocess.check_output(['kubectl','-n','argocd','get','applications','-o','json'],text=True)
apps=json.loads(raw)['items']; by={a['metadata']['name']:a for a in apps}
required={'flowbase-prod':'OutOfSync','flowbase-staging':'Synced'}
if not set(required).issubset(by): sys.exit('[FAIL] Checkout Applications missing')
extra=set(by)-set(required)-{f'flowbase-{svc}-{env}' for svc in ('auth','billing','catalog','gateway','inventory','notifications','orders','reporting','search') for env in ('prod','staging')}
if extra: sys.exit('[FAIL] Unexpected Applications exist: '+str(sorted(extra)))
for name,expected in required.items():
 a=by[name]
 if a['spec']['project']!='flowbase' or 'automated' in a['spec'].get('syncPolicy',{}):
  sys.exit('[FAIL] Checkout Project or SyncPolicy unexpected: '+name)
 if a.get('status',{}).get('sync',{}).get('status')!=expected or a.get('status',{}).get('health',{}).get('status')!='Healthy':
  sys.exit('[FAIL] Unexpected Checkout state; do NOT alter current demo: '+name)
print('[PASS] Existing Checkout demo preserved: staging Synced, production OutOfSync, both Healthy')
PY
kubectl -n argocd apply --dry-run=server -f showcase/applications.yaml >/dev/null
kubectl -n argocd apply -f showcase/applications.yaml
# Metadata-only owner / environment tags on the original two Checkout Applications; no spec change.
kubectl -n argocd label application flowbase-prod \
  flowbase.example/service=checkout flowbase.example/environment=prod \
  flowbase.example/team=team-commerce --overwrite
kubectl -n argocd label application flowbase-staging \
  flowbase.example/service=checkout flowbase.example/environment=staging \
  flowbase.example/team=team-commerce --overwrite
printf '\n[PASS] 18 mock Applications registered + metadata-only Checkout owner labels.\n'
printf '[NEXT] Log in to Argo CD CLI and run ./scripts/initial-sync-showcase.sh\n'
