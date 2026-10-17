"""Helm rendering tests for both environments and versions (requires helm and pyyaml)."""
from pathlib import Path
import subprocess
import yaml

ROOT = Path(__file__).resolve().parents[1]
CHART = ROOT / "charts/flowbase-web"


def render(env: str, version: str):
    # Scenario files are used to verify v1 and v2 without mutating values-* in repo.
    rendered = subprocess.check_output(
        ["helm", "template", "flowbase", str(CHART),
         "-f", str(ROOT / f"scenarios/values-{env}-{version}.yaml")],
        text=True,
    )
    objects = {doc["kind"]: doc for doc in yaml.safe_load_all(rendered) if doc}
    assert set(objects) == {"Service", "Deployment", "ConfigMap"}, set(objects)
    return objects


def check_rendered():
    for env, nodeport in (("staging", 30082), ("prod", 30081)):
        for version, mode in (("v1", "multi-step"), ("v2", "one-click")):
            objects = render(env, version)
            svc = objects["Service"]["spec"]
            dep = objects["Deployment"]["spec"]
            html = objects["ConfigMap"]["data"]["index.html"]
            assert svc["type"] == "NodePort"
            assert svc["ports"][0]["nodePort"] == nodeport
            assert dep["replicas"] == 1
            assert dep["template"]["metadata"]["annotations"]["checksum/page"]
            assert f'data-version="{version}.0"' in html
            assert f'data-mode="{mode}"' in html
            assert ("1クリックで購入する" in html) == (version == "v2")
            assert "実際の購入・決済" in html
            print(f"PASS: helm template {env} {version} / NodePort {nodeport} / {mode}")


if __name__ == "__main__":
    check_rendered()
