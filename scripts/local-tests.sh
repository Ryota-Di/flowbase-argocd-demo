#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v helm >/dev/null || { echo 'helm missing' >&2; exit 1; }
if [[ ! -x .venv/bin/python ]]; then python3 -m venv .venv; fi
if ! .venv/bin/python -c 'import yaml' >/dev/null 2>&1; then .venv/bin/python -m pip install 'pyyaml>=6,<7'; fi
.venv/bin/python tests/gitops_checks.py
helm lint charts/flowbase-web -f charts/flowbase-web/values-staging.yaml
helm lint charts/flowbase-web -f charts/flowbase-web/values-prod.yaml
