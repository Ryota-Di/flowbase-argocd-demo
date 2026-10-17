#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh
if [[ $# -ne 1 || ! "$1" =~ ^(staging|prod|reset)$ ]]; then
  echo 'Usage: ./scripts/prepare-pr.sh staging|prod|reset' >&2
  exit 1
fi
MODE="$1"
require_main_clean
case "$MODE" in
  staging)
    files=(charts/flowbase-web/values-staging.yaml)
    label='release staged checkout v2'
    ;;
  prod)
    files=(charts/flowbase-web/values-prod.yaml)
    label='promote validated checkout v2 to production'
    ;;
  reset)
    files=(charts/flowbase-web/values-staging.yaml charts/flowbase-web/values-prod.yaml)
    label='reset FlowBase demo to v1'
    ;;
esac
BRANCH="demo/${MODE}-$(date +%Y%m%d-%H%M%S)-$$"
git switch -c "$BRANCH"
if [[ "$MODE" == reset ]]; then
  cp scenarios/values-staging-v1.yaml charts/flowbase-web/values-staging.yaml
  cp scenarios/values-prod-v1.yaml charts/flowbase-web/values-prod.yaml
else
  cp "scenarios/values-${MODE}-v2.yaml" "charts/flowbase-web/values-${MODE}.yaml"
fi
git add -- "${files[@]}"
if git diff --cached --quiet; then
  git switch main
  git branch -D "$BRANCH" >/dev/null
  echo 'Target state already matches main: nothing to open as PR.'
  exit 0
fi
git commit -m "demo: $label"
git push -u origin "$BRANCH"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  if ! gh pr create --base main --head "$BRANCH" --title "demo: $label" \
    --body "FlowBase local demo. Review the environment-specific Helm values. For prod: merge only AFTER staging v2 is verified. CI/reviewer approval may need separate configuration."; then
    echo "PR creation failed; use GitHub UI to create a PR from $BRANCH." >&2
  fi
else
  echo "Open GitHub -> Pull requests -> New pull request, with head branch: $BRANCH"
fi
git switch main
cat <<MSG
Branch: $BRANCH
Next: Review PR -> (reviewer approval if configured) -> Merge to main via GitHub.
Then run: ./scripts/after-merge.sh
Production PR must not be merged before staging v2 is verified.
MSG
