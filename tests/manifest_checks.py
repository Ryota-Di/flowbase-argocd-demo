"""Offline kubectl-stub test of the generated AppProject/Application manifests.

Not an Argo CD admission/conformance test. It tests script output and restrictions.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import yaml

ROOT = Path(__file__).resolve().parents[1]


def test_app_manifest():
    with tempfile.TemporaryDirectory(prefix="flowbase-manifest-") as tmp:
        d = Path(tmp)
        shim = d / "kubectl"
        shim.write_text('''#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == 'config current-context' ]]; then
  echo kind-argocd-demo
elif [[ "$*" == *'create namespace'* ]]; then
  ns="$3"
  printf 'apiVersion: v1\\nkind: Namespace\\nmetadata:\\n  name: %s\\n' "$ns"
elif [[ "$*" == *'apply -f -'* ]]; then
  cat > "${MANIFEST_OUTPUT}"
else
  exit 0
fi
''')
        shim.chmod(0o755)
        env = dict(os.environ, PATH=f"{d}:{os.environ['PATH']}", MANIFEST_OUTPUT=str(d / "latest.yml"))
        subprocess.run(["bash", "scripts/create-apps.sh", "https://github.com/demo-user/flowbase-argocd-demo.git"],
                       cwd=ROOT, env=env, check=True, capture_output=True, text=True)
        docs = [doc for doc in yaml.safe_load_all((d / "latest.yml").read_text()) if doc]
        assert [d["kind"] for d in docs] == ["AppProject", "Application", "Application"]
        project = docs[0]["spec"]
        assert project["sourceRepos"] == ["https://github.com/demo-user/flowbase-argocd-demo.git"]
        assert {dest["namespace"] for dest in project["destinations"]} == {"flowbase-staging", "flowbase-prod"}
        assert all(dest["server"] == "https://kubernetes.default.svc" for dest in project["destinations"])
        assert "clusterResourceWhitelist" not in project
        assert all(app["spec"]["project"] == "flowbase" for app in docs[1:])
        assert all(app["spec"]["syncPolicy"] == {} for app in docs[1:])
        assert {app["spec"]["destination"]["namespace"] for app in docs[1:]} == {"flowbase-staging", "flowbase-prod"}
        print("APP MANIFEST PASS: 1 restricted project + 2 manual-sync applications")


if __name__ == "__main__":
    test_app_manifest()
