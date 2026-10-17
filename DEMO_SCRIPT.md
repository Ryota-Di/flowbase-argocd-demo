# FlowBase：17分のライブデモ進行表（v3）

> 目的：単なる機能一覧ではなく、顧客課題→対応策→Argo CD固有の貢献を対応付ける。PRレビュー・CIはGitHubの機能、Argo CDは差分確認・同期・リソース可視化を担う。

| 時間 | 実演と操作 | 顧客にとっての意味 | 当日のチェック |
|---|---|---|---|
| 0:00–2:00 | FlowBase（40アプリ/8チーム/SRE5人）のリリース待ち。Before/Afterの役割分担とArgo CD画面の2環境を示す | 手動代行の削減は**運用権限移譲**、Argo CDは**可視化/Sync** | v1 staging/prod Synced / Healthy |
| 2:00–6:00 | staging用PRのChecks・差分→merge（準備済みPR）、`./scripts/after-merge.sh`、Argo CD Refresh→Diff→手動Sync、v2画面1クリック操作 | Gitを基準に、開発者が変更内容を確認してリリース | stagingだけv2、prodはv1 |
| 6:00–10:00 | staging検証後、prod用PR merge→Argo CD Diff→手動Sync→prod v2を確認 | 環境毎のリリース時点をコントロール | prod v2、Synced / Healthy |
| 10:00–14:00 | `./scripts/drift-image.sh`→OutOfSync→Deployment Diff→手動Sync→復旧、可能ならCLI確認 | 意図しない実状態との差分を可視化し、Gitに戻せる | 正しいimageタグ、Synced / Healthy |
| 14:00–17:00 | 各機能の効果と限界、GitHubレビュー・CI・監視との役割、周辺ツールとの役割分担、質疑 | 課題ごとに責任を区分して納得感を高める | 自動ロールバック等は主張しない |

## 準備

1. 原則、`./scripts/reset-v1.sh`→reset PR merge→`./scripts/after-merge.sh`→Argo CD 2環境Sync→`./scripts/check.sh v1 v1`。練習時間の制約がある場合だけ`--direct-demo-only`を使用。
2. `./scripts/release-staging-v2.sh` と `./scripts/release-prod-v2.sh` で**別々のPRを事前作成してopenのまま**にする。PR Checksがgreen。stage→prodの順序を守る。
3. 画面タブ: GitHub PR、Argo CD Applications、Staging http://localhost:8082、Production http://localhost:8081、Terminal。
4. `demo-developer`でArgo CDにログイン。右上にアカウントが見えなくても事前に確認する。
5. StagingとProductionの画面に「未購入」状態を表示。動作確認で更新し必要なら再読込。

## 口頭で説明する軸

- **Fast**: SREによる手動リリース代行を減らせるのは、PR/CIを前提に開発チームにSync権限を渡す運用にしたため。Argo CDはその操作を差分可視化とGUI操作で支える。
- **Safe**: GitHub側のレビューとCIを維持する。Argo CD側ではAppProjectとRBACで作業範囲を制限、差分を確認して手動Sync。RBAC・手動Syncだけで誤設定を完全防止するわけではない。
- **Scale**: 複数環境・アプリの状態を標準のUIで管理できる設計。40→80アプリでの性能やSRE工数削減をこの2アプリPoCで実証したとは言わない。
- **Drift**: OutOfSyncは期待状態との構成差分。業務障害の自動検出や根本原因特定とは異なる。

## 途中失敗した場合

- GitHub merge/反映に時間がかかる: PR mergeを確認してArgo CD Refresh。自動Syncには変更しない。
- `demo-developer`権限でDiff/Sync不可: 一旦adminログインで復旧、**このデモでは本番権限制御の完成を証明していない**と正確に補足する。
- イメージドリフトからの復旧が不安定: `./scripts/drift-replicas.sh` を予備として使い、構成差分→Syncを演示。
- 画面が壊れる/ネットが不安定: 事前録画・静止画を用いる。ただし録画とライブ操作は区別して説明。

**プレゼンではCI/PR承認をArgo CDの効果として数えないこと。**
