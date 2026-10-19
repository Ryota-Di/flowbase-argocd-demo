"""CI and local static acceptance: validate every one of 18 mock Applications and renders."""
from pathlib import Path
import subprocess
import yaml

root = Path(__file__).resolve().parents[1]
services = {
    'auth': 'team-platform', 'billing': 'team-finance', 'catalog': 'team-merchandising',
    'gateway': 'team-platform', 'inventory': 'team-fulfillment', 'notifications': 'team-engagement',
    'orders': 'team-commerce', 'reporting': 'team-analytics', 'search': 'team-discovery',
}
assert len(set(services.values()) | {'team-commerce'}) == 8
profiles=yaml.safe_load((root/'showcase/chart/values.yaml').read_text())['serviceSettings']
assert set(profiles)==set(services)
assert len({profile['key'] for profile in profiles.values()})==9
names = {f'flowbase-{svc}-{env}' for svc in services for env in ('prod', 'staging')}
applications = [a for a in yaml.safe_load_all((root/'showcase/applications.yaml').read_text()) if a]
assert len(applications) == 18
assert {a['metadata']['name'] for a in applications} == names
assert not (names & {'flowbase-prod', 'flowbase-staging'})
for a in applications:
    assert a['apiVersion'] == 'argoproj.io/v1alpha1' and a['kind'] == 'Application'
    meta = a['metadata']; spec = a['spec']; labels = meta['labels']
    assert meta['namespace'] == 'argocd'
    assert labels['flowbase.example/showcase'] == 'true'
    svc = labels['flowbase.example/service']; env = labels['flowbase.example/environment']
    team = labels['flowbase.example/team']
    assert svc in services and env in ('prod', 'staging') and team == services[svc]
    assert meta['name'] == f'flowbase-{svc}-{env}'
    assert spec['project'] == 'flowbase' and spec['syncPolicy'] == {}
    assert spec['source']['repoURL'] == 'https://github.com/Ryota-Di/flowbase-argocd-demo.git'
    assert spec['source']['targetRevision'] == 'main' and spec['source']['path'] == 'showcase/chart'
    assert spec['destination']['namespace'] == 'flowbase-' + env
    assert spec['destination']['server'] == 'https://kubernetes.default.svc'
    params = {p['name']:p['value'] for p in spec['source']['helm']['parameters']}
    assert params == {'service': svc, 'environment': env, 'team': team}
    output = subprocess.check_output(['helm','template',meta['name'],str(root/'showcase/chart'),
                                      '--set',f'service={svc}','--set',f'environment={env}',
                                      '--set',f'team={team}'],text=True)
    objs = [o for o in yaml.safe_load_all(output) if o]
    assert len(objs) == 1, meta['name']
    cm = objs[0]
    assert cm['kind'] == 'ConfigMap' and cm['metadata']['name'] == f'flowbase-{svc}-{env}'
    assert cm['metadata']['labels']['flowbase.example/environment'] == env
    assert cm['data']['service'] == svc and cm['data']['ownerTeam'] == team
    assert cm['data']['environment'] == env
    assert 'configuration-only simulation' == cm['data']['deploymentModel']
    settings=yaml.safe_load(cm['data']['settings.yaml'])
    assert settings['service']==svc and settings['environment']==env
    assert settings['releasePolicy']=='manual'
    assert settings['settings']=={profiles[svc]['key']:profiles[svc]['value']}
for env in ('prod','staging'):
    values = yaml.safe_load((root/f'charts/flowbase-web/values-{env}.yaml').read_text())
    assert values['image']['repository'] == 'flowbase-web'
    assert values['image']['tag'] == values['release']['version'] == 'v2'
for shell in (root/'scripts').glob('*.sh'):
    subprocess.run(['bash','-n',str(shell)],check=True)
print('[PASS] 18/18 Helm renders, unique service-specific mock settings, 9 services x 2 env, 8 owner teams, existing Checkout values unchanged')
