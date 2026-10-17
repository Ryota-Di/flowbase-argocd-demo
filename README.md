# FlowBase GitOps demo (local kind image mode)

This repository contains Kubernetes deployment settings only. Application source and its CI live in [flowbase-web](https://github.com/Ryota-Di/flowbase-web). Argo CD watches *this* repository, and manual Sync is used for releases. Images `flowbase-web:v1` and `flowbase-web:v2` must be built and loaded into `kind-argocd-demo` *before* the corresponding Argo CD Sync. No container registry is used. `imagePullPolicy: Never` intentionally forbids registry pulls. Both environments run in namespaces in one local kind cluster, not real isolated production.

- `./scripts/check.sh v1 v1`, `v2 v1`, `v2 v2`: assert GitOps values, deployed image, pull policy, HTTP version, Synced / Healthy.
- `./scripts/drift-replicas.sh --demo-only`: Staging live replicas 1 → 2; refresh/diff/manual Sync to restore.
- No GitHub Actions job publishes application images; the app repo CI only builds for testing.
