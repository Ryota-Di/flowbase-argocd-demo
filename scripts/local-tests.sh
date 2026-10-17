#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v python3 >/dev/null; then echo '[FAIL] python3 is required' >&2; exit 1; fi
if ! command -v helm >/dev/null; then echo '[FAIL] helm is required' >&2; exit 1; fi

echo '[1/3] Creating/reusing isolated Python test environment'
if [[ ! -x .venv/bin/python ]]; then
  python3 -m venv .venv
fi
if ! .venv/bin/python -c 'import yaml' >/dev/null 2>&1; then
  .venv/bin/python -m pip install 'pyyaml>=6,<7'
fi

echo '[2/3] Checking shell scripts, manifests and release branches'
.venv/bin/python tests/static_checks.py
.venv/bin/python tests/git_flow_checks.py
.venv/bin/python tests/manifest_checks.py
.venv/bin/python tests/checkpoints_checks.py

echo '[3/3] Linting and rendering four environment/version combinations'
helm lint charts/flowbase-web -f charts/flowbase-web/values-staging.yaml
helm lint charts/flowbase-web -f charts/flowbase-web/values-prod.yaml
.venv/bin/python tests/render_checks.py
echo '[PASS] Offline tests passed. This does not verify a running Kubernetes cluster.'
