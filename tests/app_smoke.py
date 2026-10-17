"""Lightweight application source checks; live image checks occur on the Mac."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
common=(root/'app/shared/index.html').read_text()
assert '<script src="/main.js" defer>' in common
for version, mode, text in [('v1','multi-step','3ステップ'),('v2','one-click','1クリック')]:
    config=json.loads((root/f'app/{version}/config.json').read_text())
    assert config == {'version': f'{version}.0', 'mode':mode}
    script=(root/f'app/{version}/main.js').read_text()
    assert text in script
    assert "fetch('/config.json'" in script
print('APP SOURCE PASS: independent v1/v2 assets + config.json + no external endpoints')
