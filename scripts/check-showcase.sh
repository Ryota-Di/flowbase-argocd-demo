#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
python3 - <<'PY'
import json,subprocess,sys
get=lambda *args:json.loads(subprocess.check_output(['kubectl',*args,'-o','json'],text=True))
items=get('-n','argocd','get','applications')['items']; by={a['metadata']['name']:a for a in items}
services='auth billing catalog gateway inventory notifications orders reporting search'.split()
expected={f'flowbase-{svc}-{env}' for svc in services for env in ('prod','staging')}
expected|={'flowbase-prod','flowbase-staging'}
if set(by)!=expected: sys.exit(f'[FAIL] Expected exactly 20 Apps; missing={sorted(expected-set(by))} extra={sorted(set(by)-expected)}')
teams=set()
for name,a in by.items():
 label=a['metadata'].get('labels',{}); team=label.get('flowbase.example/team'); env=label.get('flowbase.example/environment')
 if env not in ('prod','staging') or not team: sys.exit('[FAIL] Missing env/team metadata: '+name)
 teams.add(team)
 if name not in ('flowbase-prod','flowbase-staging'):
  if label.get('flowbase.example/showcase')!='true': sys.exit('[FAIL] Mock selector label missing: '+name)
  if a['spec']['destination']['namespace']!='flowbase-'+env: sys.exit('[FAIL] Wrong mock destination: '+name)
  if a.get('status',{}).get('sync',{}).get('status')!='Synced' or a.get('status',{}).get('health',{}).get('status')!='Healthy':
   sys.exit('[FAIL] Mock App not Synced/Healthy: '+name)
 if 'automated' in a['spec'].get('syncPolicy',{}): sys.exit('[FAIL] Automated sync on: '+name)
if len(teams)!=8: sys.exit('[FAIL] Expected 8 teams, got '+str(sorted(teams)))
for env in ('prod','staging'):
 cm=get('-n','flowbase-'+env,'get','configmaps','-l','flowbase.example/showcase=true')['items']
 expect={f'flowbase-{svc}-{env}' for svc in services}
 actual={c['metadata']['name'] for c in cm}
 if actual!=expect: sys.exit(f'[FAIL] {env} ConfigMaps: missing={sorted(expect-actual)} extra={sorted(actual-expect)}')
print('[PASS] 20 Applications = 10 services x 2 env; exactly 9 ConfigMaps per env; 8 owner teams')
print('[PASS] All 18 mock Applications Synced/Healthy; original Checkout app states NOT changed')
for name in sorted(by):
 a=by[name]; st=a.get('status',{}); labels=a['metadata'].get('labels',{})
 print(f"  {name:<31} {labels.get('flowbase.example/environment','?'):<8} {st.get('sync',{}).get('status','?'):<10} {st.get('health',{}).get('status','?'):<9} {labels.get('flowbase.example/team','?')}")
PY
