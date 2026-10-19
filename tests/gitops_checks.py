"""Checkout chart smoke tests: production/staging environment badge and v1/v2 image."""
from pathlib import Path
import json, subprocess, yaml
root=Path(__file__).resolve().parents[1]
for env,port in [('staging',30082),('prod',30081)]:
 values=yaml.safe_load((root/f'charts/flowbase-web/values-{env}.yaml').read_text())
 assert values['image']['repository']=='flowbase-web'
 assert values['image']['tag'] in ('v1','v2')
 assert values['release']['version']==values['image']['tag']
 assert values['environment']==env
 assert values['service']['nodePort']==port
 raw=subprocess.check_output(['helm','template','flowbase',str(root/'charts/flowbase-web'),'-f',str(root/f'charts/flowbase-web/values-{env}.yaml')],text=True)
 objs=[a for a in yaml.safe_load_all(raw) if a]
 assert {o['kind'] for o in objs}=={'Service','Deployment','ConfigMap'}
 dep=next(o for o in objs if o['kind']=='Deployment');svc=next(o for o in objs if o['kind']=='Service');cm=next(o for o in objs if o['kind']=='ConfigMap')
 assert cm['metadata']['name']=='flowbase-checkout-environment'
 assert json.loads(cm['data']['environment.json'])=={'environment':env,'service':'checkout'}
 c=dep['spec']['template']['spec']['containers'][0]
 assert c['image']==f"flowbase-web:{values['image']['tag']}"
 assert c['imagePullPolicy']=='Never' and c['ports'][0]['containerPort']==8080
 assert c['securityContext']['readOnlyRootFilesystem'] is True
 assert svc['spec']['ports'][0]['targetPort']==8080 and svc['spec']['ports'][0]['nodePort']==port
 assert any(v.get('name')=='environment' and v.get('configMap',{}).get('name')=='flowbase-checkout-environment' for v in dep['spec']['template']['spec']['volumes'])
 assert any(m.get('name')=='environment' and m.get('subPath')=='environment.json' and m.get('mountPath')=='/usr/share/nginx/html/environment.json' for m in c['volumeMounts'])
 assert len(dep['spec']['template']['metadata']['annotations'].get('checksum/environment',''))==64
 print(f'[PASS] {env}: image={c["image"]}, env metadata from Helm-managed ConfigMap, readonly mount')
for p in (root/'scripts').glob('*.sh'):subprocess.run(['bash','-n',str(p)],check=True)
print('[PASS] Checkout Helm ConfigMap/Deployment/Service and scripts')
