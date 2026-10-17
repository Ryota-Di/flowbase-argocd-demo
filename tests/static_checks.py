"""Source-level smoke tests; they do NOT replace a running Kubernetes integration test."""
from pathlib import Path
import subprocess
import yaml

ROOT = Path(__file__).resolve().parents[1]


def check_static():
    kind = yaml.safe_load((ROOT / "kind-config.yaml").read_text())
    mappings = kind["nodes"][0]["extraPortMappings"]
    assert {(item["containerPort"], item["hostPort"], item["listenAddress"]) for item in mappings} == {
        (30081, 8081, "127.0.0.1"), (30082, 8082, "127.0.0.1")
    }
    for env, nodeport in (("prod", 30081), ("staging", 30082)):
        for ver, mode in (("v1", "multi-step"), ("v2", "one-click")):
            doc = yaml.safe_load((ROOT / f"scenarios/values-{env}-{ver}.yaml").read_text())
            assert doc["service"]["nodePort"] == nodeport
            assert doc["page"]["checkoutMode"] == mode
        current = yaml.safe_load((ROOT / f"charts/flowbase-web/values-{env}.yaml").read_text())
        assert current in [
            yaml.safe_load((ROOT / f"scenarios/values-{env}-{ver}.yaml").read_text())
            for ver in ("v1", "v2")
        ], f"Unexpected checked-in {env} values"
    for script in (ROOT / "scripts").glob("*.sh"):
        subprocess.run(["bash", "-n", str(script)], check=True)
    create = (ROOT / "scripts/create-apps.sh").read_text()
    assert "project: flowbase" in create and "syncPolicy: {}" in create
    assert "namespaceResourceWhitelist" in create
    assert "namespace: argocd" not in create.split("spec:", 1)[1].split("---", 1)[0]
    assert "project: default" not in create
    print("STATIC CHECKS PASS: kind, scenarios, shell syntax, AppProject guardrails")


if __name__ == "__main__":
    check_static()
