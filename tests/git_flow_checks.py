"""Offline regression test for PR branch preparation/merges/demo-only reset.

This uses temporary local Git repositories; it does not create GitHub PRs or validate
branch protections / approval rules.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def cmd(cwd, *args):
    try:
        return subprocess.check_output(args, cwd=cwd, text=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(
            f"Command failed ({exc.returncode}): {' '.join(str(a) for a in args)}\n"
            f"Output:\n{exc.output}"
        ) from exc


def test_pr_flow():
    with tempfile.TemporaryDirectory(prefix="flowbase-pr-test-") as tmp:
        base = Path(tmp)
        repo = base / "flowbase-argocd-demo"
        remote = base / "flowbase-argocd-demo-remote.git"
        shutil.copytree(ROOT, repo, ignore=shutil.ignore_patterns(".git", ".venv", "__pycache__", ".DS_Store"))
        # The CI source may itself be checked out from a staging/prod v2 PR.
        # Exercise a clean v1 -> v2 cycle independently of the current PR state.
        for env in ("staging", "prod"):
            shutil.copy2(repo / f"scenarios/values-{env}-v1.yaml",
                         repo / f"charts/flowbase-web/values-{env}.yaml")
        cmd(base, "git", "init", "--bare", str(remote))
        cmd(repo, "git", "init", "-b", "main")
        cmd(repo, "git", "config", "user.name", "Demo Tester")
        cmd(repo, "git", "config", "user.email", "demo-tester@example.invalid")
        cmd(repo, "git", "add", ".")
        cmd(repo, "git", "commit", "-m", "init")
        cmd(repo, "git", "remote", "add", "origin", str(remote))
        cmd(repo, "git", "push", "-u", "origin", "main")
        for env in ("staging", "prod"):
            cmd(repo, "bash", f"scripts/release-{env}-v2.sh")
            assert cmd(repo, "git", "branch", "--show-current").strip() == "main"
            assert not cmd(repo, "git", "status", "--porcelain").strip()
        # Both PRs were created against the same v1 base. Merge staging first,
        # then production (like merging independent GitHub PRs).
        for env in ("staging", "prod"):
            branch = next(b.strip() for b in cmd(repo, "git", "branch", "--list", f"demo/{env}-*").splitlines())
            cmd(repo, "git", "merge", "--no-ff", "-m", f"merge {env}", branch)
            cmd(repo, "git", "push", "origin", "main")
            cmd(repo, sys.executable, "tests/static_checks.py")
            values = (repo / f"charts/flowbase-web/values-{env}.yaml").read_text()
            assert 'version: "v2.0"' in values
        # Only a demo-only explicit reset bypasses PR.
        cmd(repo, "bash", "scripts/reset-v1.sh", "--direct-demo-only")
        for env in ("staging", "prod"):
            values = (repo / f"charts/flowbase-web/values-{env}.yaml").read_text()
            assert 'version: "v1.0"' in values
        assert not cmd(repo, "git", "status", "--porcelain").strip()
        print("GIT FLOW PASS: 2 independent PR branches -> staging/prod merge -> reset")


if __name__ == "__main__":
    test_pr_flow()
