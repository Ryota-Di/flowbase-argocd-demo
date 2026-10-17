"""Validate rendering of local-only image references; requires helm + PyYAML."""
from pathlib import Path
import subprocess
import yaml
root=Path(__file__).resolve().parents[1]
for env,port in [('staging',30082),('prod',30081)]:
    values=yaml.safe_load((root/f'charts/flowbase-web/values-{env}.yaml').read_text())
    assert values['image']['repository']=='flowbase-web', values
    assert values['image']['tag'] in ('v1','v2'), values
    assert values['release']['version']==values['image']['tag'], values
    assert values['service']['nodePort']==port, values
    text=subprocess.check_output(['helm','template','flowbase',str(root/'charts/flowbase-web'),'-f',str(root/f'charts/flowbase-web/values-{env}.yaml')],text=True)
    objs=[a for a in yaml.safe_load_all(text) if a]
    assert {o['kind'] for o in objs}=={'Service','Deployment'}
    dep=next(o for o in objs if o['kind']=='Deployment')
    svc=next(o for o in objs if o['kind']=='Service')
    c=dep['spec']['template']['spec']['containers'][0]
    assert c['image']==f"flowbase-web:{values['image']['tag']}"
    assert c['imagePullPolicy']=='Never'
    assert c['ports'][0]['containerPort']==8080
    assert c['securityContext']['readOnlyRootFilesystem'] is True
    assert svc['spec']['ports'][0]['targetPort']==8080
    assert svc['spec']['ports'][0]['nodePort']==port
    print(f'[PASS] {env}: {c["image"]} local-only (Never), port {port}')
for script in (root/'scripts').glob('*.sh'):
    subprocess.run(['bash','-n',str(script)],check=True)
print('[PASS] GitOps Helm templates + shell scripts')
