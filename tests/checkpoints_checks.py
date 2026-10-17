"""Offline smoke test of read-only phase checks and version-specific verifier.

Uses fake kubectl, Docker and curl; proves CLI wiring and pass/fail exits only,
NOT actual cluster functionality, Argo CD API admission or NodePort reachability.
"""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def write_tool(d: Path, name: str, body: str) -> None:
    file = d / name
    file.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + body)
    file.chmod(0o755)


def call(env: dict[str, str], *args: str, good: bool = True) -> str:
    p = subprocess.run(["bash", *args], cwd=ROOT, env=env, text=True,
                       capture_output=True, timeout=15)
    if good:
        assert p.returncode == 0, f"{args}: {p.stdout}\n{p.stderr}"
    else:
        assert p.returncode != 0, f"Expected failure, got success: {args}"
    return p.stdout + p.stderr


def main():
    with tempfile.TemporaryDirectory(prefix="flowbase-checks-") as tmp:
        d = Path(tmp)
        write_tool(d, "kubectl", r'''
case "$*" in
  'config current-context') echo kind-argocd-demo ;;
  'cluster-info') echo Kubernetes ;;
  'get nodes -o wide') echo 'demo Ready' ;;
  'wait --for=condition=Ready nodes --all --timeout=10s') echo ready ;;
  *'get service flowbase-web'*'nodePort'*)
    if [[ "$*" == *flowbase-staging* ]]; then echo 30082; else echo 30081; fi ;;
  *'get deployment flowbase-web'*'containers[0].image'* )
    echo "${STUB_IMAGE:-nginx:stable-alpine}" ;;
  *'get deployment flowbase-web'*'spec.replicas'* ) echo 1 ;;
  *'get application '*'status.sync.status'* ) echo Synced ;;
  *'get application '*'status.health.status'* ) echo Healthy ;;
  *'rollout status deployment/flowbase-web'* ) echo ready ;;
  *) echo 'stub kubectl pass' ;;
esac
''')
        write_tool(d, "docker", r'''
if [[ "$1" == port ]]; then
  if [[ "$3" == '30081/tcp' ]]; then echo '127.0.0.1:8081'; else echo '127.0.0.1:8082'; fi
else echo stub; fi
''')
        write_tool(d, "curl", r'''
if [[ "$*" == *localhost:8081* ]]; then
  v="${STUB_PROD_VERSION:-v1}"
else
  v="${STUB_STAGING_VERSION:-v1}"
fi
if [[ "$v" == v1 ]]; then mode=multi-step; else mode=one-click; fi
printf '<main data-version="%s.0" data-mode="%s">mock</main>\n' "$v" "$mode"
''')
        write_tool(d, "argocd", r'''
if [[ "$*" == *"update projects"* || "$*" == *"delete applications"* || "$*" == *"default/other"* ]]; then
  echo no
else
  echo yes
fi
''')
        env = dict(os.environ, PATH=f"{d}:{os.environ['PATH']}")
        out = call(env, "scripts/check.sh", "cluster")
        assert "[PASS] kind context" in out
        out = call(env, "scripts/check.sh", "argocd")
        assert "[PASS] Argo CD server" in out
        out = call(env, "scripts/check.sh", "apps")
        assert "[PASS] Application definitions" in out
        out = call(env, "scripts/check.sh", "v1", "v1")
        assert "[PASS] Both environments" in out
        env["STUB_STAGING_VERSION"] = "v2"
        out = call(env, "scripts/check.sh", "v2", "v1")
        assert "[PASS] Both environments" in out
        env["STUB_PROD_VERSION"] = "v2"
        out = call(env, "scripts/check.sh", "v2", "v2")
        assert "[PASS] Both environments" in out
        out = call(env, "scripts/check-rbac.sh")
        assert "[PASS] Demo developer" in out
        env["STUB_IMAGE"] = "nginx:incorrect"
        out = call(env, "scripts/check.sh", "v2", "v2", good=False)
        assert "[FAIL]" in out and "image=" in out
        out = call(env, "scripts/check.sh", "bad-phase", good=False)
        assert "Usage:" in out
        print("CHECKPOINTS PASS: phase checks, v1/v2, RBAC allow/deny and drift rejection")


if __name__ == "__main__":
    main()
