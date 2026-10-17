#!/usr/bin/env bash
# Shared guards for scripts that operate on demo infrastructure.
check_context() {
  command -v kubectl >/dev/null || { echo 'kubectl is not installed' >&2; exit 1; }
  local context
  context="$(kubectl config current-context 2>/dev/null || true)"
  if [[ "$context" != 'kind-argocd-demo' ]]; then
    echo "Safety stop: Kubernetes context '$context', expected 'kind-argocd-demo'." >&2
    exit 1
  fi
}
require_main_clean() {
  command -v git >/dev/null || { echo 'git is missing' >&2; exit 1; }
  git rev-parse --is-inside-work-tree >/dev/null
  [[ "$(git branch --show-current)" == main ]] || { echo 'Switch to main first.' >&2; exit 1; }
  [[ -z "$(git status --porcelain)" ]] || { echo 'Uncommitted or untracked files; clean them first.' >&2; exit 1; }
  git remote get-url origin >/dev/null
  git fetch -q origin main
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || {
    echo 'Local main does not match origin/main; run: git pull --ff-only origin main' >&2
    exit 1
  }
}
