"""Fail closed before first public push. This is a heuristic, not a guarantee.

Checks the STAGED commit payload, not arbitrary local files. It is deliberately
conservative on identity and credential patterns. Does not print secret values.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys


def git(*args):
    return subprocess.check_output(["git", *args], stderr=subprocess.DEVNULL)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--staged", action="store_true")
    args = p.parse_args()
    if not args.staged:
        p.error("Pass --staged (inspect staged files before the first commit)")
    email = git("config", "--get", "user.email").decode().strip()
    if not email.lower().endswith("@users.noreply.github.com"):
        raise SystemExit("[FAIL] Public commit identity is not a GitHub noreply email. Set repo-local git user.email before push.")
    names = [s for s in git("diff", "--cached", "--name-only", "-z").split(b"\0") if s]
    if not names:
        raise SystemExit("[FAIL] Nothing staged. Not creating an empty initial commit.")
    patterns = {
        "private key block": b"-----BEGIN " + rb"(?:[A-Z ]+ )?PRIVATE KEY-----",
        "GitHub token": rb"(?:ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}",
        "AWS access key": rb"(?:AKIA|ASIA)[0-9A-Z]{16}",
        "SSH private key header": b"-----BEGIN OPEN" + b"SSH PRIVATE KEY-----",
    }
    forbidden_names = re.compile(rb"(^|/)(?:\.env(?:\..*)?|id_rsa|id_ed25519|credentials\.json|config\.json)$|\.(?:pem|p12|pfx|key|kubeconfig)$", re.I)
    bad = []
    for raw in names:
        name = raw.decode("utf-8", "surrogateescape")
        if forbidden_names.search(raw):
            bad.append((name,"sensitive filename"))
            continue
        content = git("show", ":" + name)
        for kind, pattern in patterns.items():
            if re.search(pattern, content):
                bad.append((name,kind))
        if name.endswith(".md") and b"datadog" in content.lower():
            bad.append((name,"unnecessary interview/vendor reference"))
    if bad:
        for name, kind in bad:
            print(f"[FAIL] {name}: {kind}", file=sys.stderr)
        raise SystemExit("[FAIL] Review and remove flagged material before pushing to a public repository.")
    print(f"[PASS] Staged payload inspected ({len(names)} files), no matched sensitive patterns, GitHub noreply identity confirmed")
    print("[NOTE] Pattern checks cannot prove that no private information exists; review file list and diff before push.")


if __name__ == "__main__":
    main()
