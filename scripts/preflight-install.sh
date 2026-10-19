#!/usr/bin/env bash
# Guard all environmental assumptions before installing the 18 mock Applications.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
check_context
require_main_clean
for tool in kubectl helm docker python3 argocd; do
  command -v "$tool" >/dev/null || { echo "[FAIL] Required command not installed: $tool" >&2; exit 1; }
done
[[ -f showcase/applications.yaml && -f tests/showcase_checks.py ]] || {
  echo '[FAIL] v10 showcase files missing from checked-out GitOps main' >&2; exit 1;
}
[[ -x .venv/bin/python ]] || { echo '[FAIL] Python venv missing; first run ./scripts/local-tests.sh' >&2; exit 1; }
.venv/bin/python - <<'PY'
import json, pathlib, subprocess, sys, urllib.request, yaml
root=pathlib.Path.cwd()
def need(ok,msg):
 if not ok: sys.exit('[FAIL] '+msg)
def get(*args): return json.loads(subprocess.check_output(['kubectl',*args,'-o','json'],text=True))
for env in ('prod','staging'):
 values=yaml.safe_load((root/f'charts/flowbase-web/values-{env}.yaml').read_text())
 need(values['image']['repository']=='flowbase-web' and values['image']['tag']=='v2' and values['release']['version']=='v2', env+' Git must target v2')
items=get('-n','argocd','get','applications')['items']
by={a['metadata']['name']:a for a in items}
need(set(by)=={'flowbase-prod','flowbase-staging'}, 'Existing 2 Apps must be only Applications before install')
for env in ('prod','staging'):
 a=by['flowbase-'+env]; st=a.get('status',{})
 expected='OutOfSync' if env=='prod' else 'Synced'
 need(st.get('sync',{}).get('status')==expected and st.get('health',{}).get('status')=='Healthy',env+' Application has unexpected status')
 need('automated' not in a['spec'].get('syncPolicy',{}),env+' auto Sync enabled')
 need(a['spec']['project']=='flowbase',env+' Project unexpected')
 d=get('-n','flowbase-'+env,'get','deployment','flowbase-web')['spec']
 expected_version='v1' if env=='prod' else 'v2'
 need(d['replicas']==1 and d['template']['spec']['containers'][0]['image']=='flowbase-web:'+expected_version,env+' live deployment unexpected')
 need(d['template']['metadata']['annotations'].get('flowbase.example/release')==expected_version,env+' release annotation unexpected')
 try:
  with urllib.request.urlopen(f'http://localhost:{8081 if env=="prod" else 8082}/version.json',timeout=5) as resp:
   version=json.load(resp)['version']
 except Exception as exc: sys.exit(f'[FAIL] Cannot read {env} HTTP /version.json: {exc}')
 need(version==expected_version,env+' HTTP version unexpected')
print('[PASS] Git v2 both environments; Staging live v2 Synced Healthy; Production live v1 OutOfSync Healthy')
PY
for tag in v1 v2; do
  docker exec argocd-demo-control-plane crictl images | grep -Eq "^docker.io/library/flowbase-web[[:space:]]+${tag}[[:space:]]" || {
    echo "[FAIL] flowbase-web:${tag} is missing from kind control-plane" >&2; exit 1;
  }
done
printf '[PASS] local kind images v1+v2 available; preflight complete; safe to register mock Apps\n'
