#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
python3 - "${1:-}" <<'PY'
import json, pathlib, subprocess, sys, urllib.request
mode=sys.argv[1]
if mode not in ('before','after-a','after-b'):
 sys.exit('Usage: ./scripts/demo-state.sh before|after-a|after-b')
root=pathlib.Path.cwd()
def run(*args): return subprocess.check_output(args,text=True).strip()
def kjson(*args): return json.loads(run('kubectl',*args,'-o','json'))
def need(cond,message):
 if not cond: sys.exit('[FAIL] '+message)
for env in ('prod','staging'):
 values=(root/f'charts/flowbase-web/values-{env}.yaml').read_text()
 need('\n  tag: v2\n' in values and '\n  version: v2\n' in values,f'Git {env} does not target v2')
apps=kjson('-n','argocd','get','applications')['items']; by={a['metadata']['name']:a for a in apps}
services='auth billing catalog gateway inventory notifications orders reporting search'.split()
expected={f'flowbase-{svc}-{env}' for svc in services for env in ('prod','staging')}
expected|={'flowbase-prod','flowbase-staging'}
need(set(by)==expected,'Expected 20 named Apps (10 services x 2 env)')
need(len({a['metadata'].get('labels',{}).get('flowbase.example/team') for a in apps})==8,'Expected exactly 8 team labels')
for name in expected-{'flowbase-prod','flowbase-staging'}:
 app=by[name]
 need(app['status']['sync']['status']=='Synced' and app['status']['health']['status']=='Healthy',name+' not Synced/Healthy')
exp_prod={'before':('v1',1,'OutOfSync'),'after-a':('v2',1,'Synced'),'after-b':('v2',2,'OutOfSync')}[mode]
for env in ('staging','prod'):
 name='flowbase-'+env; a=by[name]; st=a.get('status',{})
 exp=('v2',1,'Synced') if env=='staging' else exp_prod
 version,replicas,sync=exp
 need('automated' not in a['spec'].get('syncPolicy',{}),name+' auto-sync unexpectedly enabled')
 need(st.get('sync',{}).get('status')==sync,name+' status '+str(st.get('sync',{}).get('status'))+' expected '+sync)
 need(st.get('health',{}).get('status')=='Healthy',name+' Health not Healthy')
 dep=kjson('-n','flowbase-'+env,'get','deployment','flowbase-web')['spec']
 con=dep['template']['spec']['containers'][0]
 need(con['name']=='web' and con['image']=='flowbase-web:'+version,name+' image mismatch')
 need(con['imagePullPolicy']=='Never',name+' pull policy mismatch')
 need(dep['replicas']==replicas,name+' replicas mismatch')
 annotation=dep['template']['metadata']['annotations'].get('flowbase.example/release')
 need(annotation==version,name+' release annotation mismatch: '+str(annotation)+' != '+version)
 try:
  port=8081 if env=='prod' else 8082
  with urllib.request.urlopen(f'http://localhost:{port}/version.json',timeout=4) as resp:
   data=json.load(resp)
 except Exception as e: sys.exit(f'[FAIL] HTTP {env}: {e}')
 need(data['version']==version,f'HTTP {env} version {data["version"]} != {version}')
 try:
  with urllib.request.urlopen(f'http://localhost:{port}/environment.json',timeout=4) as resp:
   env_metadata=json.load(resp)
 except Exception as exc: sys.exit(f'[FAIL] Environment metadata {env}: {exc}')
 need(env_metadata.get('environment')==env,f'Wrong environment metadata: {env_metadata}')
 print(f'[PASS] {name}: Git=v2 Live={version} replicas={replicas} release={annotation} Sync={sync} Health=Healthy HTTP={version}')
for env in ('prod','staging'):
 cm=kjson('-n','flowbase-'+env,'get','configmaps','-l','flowbase.example/showcase=true')['items']
 need(len(cm)==9,f'{env} expected exactly 9 showcase ConfigMaps')
print(f'[PASS] DEMO CHECKPOINT: {mode} (20 Applications, 8 teams, 9 mock ConfigMaps per environment)')
PY
