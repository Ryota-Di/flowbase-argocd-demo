#!/usr/bin/env bash
# Safe initial push and Argo CD application registration; never overwrites remote main.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./scripts/_lib.sh

fail() { echo "[FAIL] $*" >&2; exit 1; }
[[ $# == 1 ]] || fail 'Usage: ./scripts/connect-github.sh https://github.com/YOUR_USERNAME/flowbase-argocd-demo.git'
REPO_URL="$1"
[[ "$REPO_URL" =~ ^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+\.git$ ]] || fail 'Use a public GitHub HTTPS .git URL (no credentials).'
check_context
kubectl -n argocd get deployment argocd-server >/dev/null || fail 'Run ./scripts/bootstrap.sh first.'

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo '[1/3] Initializing local Git repository'
  git init -b main
fi
[[ "$(git rev-parse --show-toplevel)" == "$(pwd)" ]] || fail 'Inside another repository; use an independent folder.'
[[ "$(git branch --show-current)" == main ]] || fail 'Please switch to main before connecting.'

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo '[1/3] Preparing a minimum-file, privacy-checked initial commit'
  # Staging a fixed allowlist rather than blindly running `git add .`.
  files=(
    .gitignore .github/workflows/validate.yml
    charts/flowbase-web/Chart.yaml charts/flowbase-web/values.yaml
    charts/flowbase-web/values-staging.yaml charts/flowbase-web/values-prod.yaml
    charts/flowbase-web/templates/deployment.yaml
    charts/flowbase-web/templates/configmap.yaml
    charts/flowbase-web/templates/service.yaml
    kind-config.yaml
    scenarios/values-prod-v1.yaml scenarios/values-prod-v2.yaml
    scenarios/values-staging-v1.yaml scenarios/values-staging-v2.yaml
    scripts/_lib.sh scripts/after-merge.sh scripts/bootstrap.sh
    scripts/check-rbac.sh scripts/check.sh scripts/configure-demo-user.sh
    scripts/connect-github.sh scripts/create-apps.sh scripts/drift-image.sh
    scripts/drift-replicas.sh scripts/local-tests.sh scripts/prepare-pr.sh
    scripts/release-prod-v2.sh scripts/release-staging-v2.sh
    scripts/reset-v1.sh scripts/start-ui.sh scripts/verify.sh
    tests/checkpoints_checks.py tests/git_flow_checks.py
    tests/manifest_checks.py tests/render_checks.py tests/static_checks.py tests/security_checks.py
    DEMO_SCRIPT.md HOTFIX.md QUICKSTART.md README.md REVIEW.md START_HERE.md SECURITY.md
  )
  for f in "${files[@]}"; do [[ -f "$f" ]] || fail "Expected project file missing: $f"; done
  git add -- "${files[@]}"
  python3 tests/security_checks.py --staged
  echo '[REVIEW] Files about to become PUBLIC:'
  git diff --cached --name-only
  if [[ "${CONFIRM_PUBLIC_PUSH:-}" != YES ]]; then
    fail 'Public push paused for review. Inspect staged list, then rerun with CONFIRM_PUBLIC_PUSH=YES ./scripts/connect-github.sh "$REPO_URL".'
  fi
  git commit -m 'demo: initialize FlowBase v1 (reviewed demo files only)'
else
  echo '[1/3] Local Git repository already has a commit'
  [[ -z "$(git status --porcelain)" ]] || fail 'Uncommitted/untracked files exist; review them before continuing.'
fi

if git remote get-url origin >/dev/null 2>&1; then
  [[ "$(git remote get-url origin)" == "$REPO_URL" ]] || fail 'Existing origin differs from the requested URL. Refusing to overwrite it.'
else
  git remote add origin "$REPO_URL"
fi

echo '[2/3] Checking remote main and pushing initial commit if empty'
# ls-remote can fail for an unreachable/nonexistent/private repo: do NOT interpret as empty.
REMOTE_HEADS="$(git ls-remote --heads origin main)" || fail 'Cannot read repository. Check public URL, network and GitHub permissions.'
if [[ -z "$REMOTE_HEADS" ]]; then
  echo 'Remote main is empty; pushing local v1 main.'
  git push -u origin main
else
  REMOTE_SHA="${REMOTE_HEADS%%$'\t'*}"
  LOCAL_SHA="$(git rev-parse HEAD)"
  [[ "$REMOTE_SHA" == "$LOCAL_SHA" ]] || fail 'Remote main has different content. Refusing to overwrite; inspect GitHub and local git history.'
  echo '[SKIP] Remote main matches local HEAD.'
fi

echo '[3/3] Creating restricted Argo CD AppProject and two Applications'
./scripts/create-apps.sh "$REPO_URL"
./scripts/check.sh apps
cat <<'MSG'
PASS: repository registered. Next:
  1. ./scripts/start-ui.sh (run in another terminal and leave open)
  2. In https://localhost:8080, log in as admin; manually SYNC both apps once.
  3. ./scripts/check.sh v1 v1  (waits for Synced/Healthy and HTTP response)
  4. ./scripts/configure-demo-user.sh  (then configure password, optional)
MSG
