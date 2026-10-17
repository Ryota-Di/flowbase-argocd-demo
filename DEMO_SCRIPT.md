# Demo storyline

1. Application repo: v1 source, test in GitHub Actions; build locally, load into kind.
2. GitOps repo: Helm points at local `flowbase-web:v1`; PR and merge; Argo CD shows Diff, explicit manual Sync, then both v1.
3. App repo: code review changes v1 to v2; CI validates source. Build `flowbase-web:v2` locally and load into kind.
4. GitOps repo: staging v1→v2 PR, merge; Argo CD shows image v1→v2 and manual Sync; Production stays v1.
5. GitOps repo: Production v1→v2 PR, merge; manual Sync.
6. Drift: change Staging replicas to 2 via kubectl. Argo CD Diff identifies Git desired=1 / live=2, manual Sync restores 1.

Correct language: CI doesn't publish images in this demo. Developers' ability to Sync is based on organizational permissions, not a direct Argo CD performance feature. GitOps diff/drift/sync/health are Argo CD's mechanisms.
