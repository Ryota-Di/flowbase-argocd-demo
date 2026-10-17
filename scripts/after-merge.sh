#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
[[ "$(git branch --show-current)" == main ]] || { echo 'Switch to main first' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo 'Working tree is not clean' >&2; exit 1; }
git pull --ff-only origin main
cat <<'MSG'
Local main updated. In Argo CD UI, Refresh the affected Application, inspect Diff,
then manually Sync (do NOT use automated sync). Confirm the desired UI version.
MSG
