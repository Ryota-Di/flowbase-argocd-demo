# FlowBase Argo CD v4 — 手順簡略化・段階検証の再レビュー

2026-10-17。対象：QUICKSTART.md、README.md、scripts/、tests/、Chart、GitHub Actions。

## 判定

**構築開始に適している（実機動作は未認定）**。v2で分散していたコマンドをフェーズ化し、誤操作を防ぐチェックと明確なPASS/FAILを増やした。Mac＋Docker Desktop＋実際のKubernetes＋GitHubへの接続は、この作業環境からはテストしていない。最終的な本番プレゼンの可否は実Macでの通し検証後に判断。

## 修正と確認

| 項目 | v2の弱点 | v4の対策 | 結果 |
|---|---|---|---|
| 前提整備 | brew/python/testコマンド多数 | 初回`chmod +x scripts/*.sh`とbrew1行、オフライン検査もbootstrap内で実行 | 静的検査済み |
| クラスタ・Argo導入 | コマンドを都度手作業で入力 | `bootstrap.sh`に集約、既存環境の再利用/安全停止 | コード検査済み、実機未実施 |
| GitHub接続 | git init/commit/remote/pushを手作業 | `connect-github.sh`で初期Pushとアプリ登録を集約 | コード検査済み、GitHub実接続未実施 |
| 状態の途中確認 | 最終verify中心 | `check.sh tools/cluster/argocd/apps/v1 v1/v2 v1/v2 v2` | スタブテスト合格 |
| 同期待ち | 状態反映直後に失敗する可能性 | `verify.sh`でArgo状態最大180秒、HTTP最大90秒の待機 | スタブテスト合格、実機未実施 |
| 復旧の安全性 | Contextは確認するが作り直しで迷いやすい | 他クラスタ操作を拒否、cluster削除なし、remote main差異時は強制上書きせず拒否 | コード検査済み |
| RBAC | UIの手動確認のみ | `check-rbac.sh`でsync許可＋重要操作の拒否をチェック | スタブテスト合格、実API未実施 |
| オフラインテストの速度 | 仮想環境をGitテストコピーに含めるおそれ | Gitフローテストで`.venv`を除外 | 合格 |
| リリース手順 | 説明が長く、GUI操作の位置が曖昧 | `QUICKSTART.md`に操作→検証の対応表 | 文章レビュー済み |

## 実行したテスト（現在のコンテナ内）

- 全Shellの `bash -n` — PASS
- `python tests/static_checks.py` — PASS
- `python tests/manifest_checks.py` — PASS（kubectlスタブでAppProject/Applicationsのmanifest検査）
- `python tests/git_flow_checks.py` — PASS（ローカルGitでstaging/prodの変更・merge・リセット）
- `python tests/checkpoints_checks.py` — PASS（kubectl/docker/curl/argocdのスタブによる各段階チェック、v1/v2、RBAC許可/拒否、異常イメージの検出）
- `tests/render_checks.py` / `helm lint` — **未実施**（現環境にHelmなし）。`local-tests.sh`とGitHub Actionsに検査工程は登録済み。
- Mac上のkind、Argo CD、NodePort HTTP、GitHub CLIでのPR作成/CI、GUIでのSync、ローカルユーザーのログイン — **未実施**。いずれも実機での通し確認が必要。

## 残存リスク・具体的な受入条件

1. ZIP展開方法によって`.sh`の実行権限が失われることがあるため、初回に`chmod +x scripts/*.sh`を実行する。
2. `bootstrap.sh`はArgo CD未導入時は公式`stable`を使う。再現性のため本番練習後は特定バージョンを固定することが望ましい。
3. GitHub HTTPS pushには認証が必要。`gh auth login`、`gh auth setup-git`を使い、空の公開Repoを作成してから接続する。
4. Dev用RBACは実際のCLIで`check-rbac.sh`がPASSするまで実証済みと扱わない。
5. GitHubに独立レビュアーとルールがなければ、「承認済みPR」を実証したと主張しない。
6. Argo CDにより自動ロールバックや自動テストが提供されるとは説明しない。サンプルは独立環境ではない擬似本番。
7. デモの手動Sync前に`check.sh v1 v1`等を実行すると待機した後に失敗する。初回Sync後、各リリースのSync後に実施する。
8. `bootstrap.sh`の再実行で既存クラスタや既存Argo CDのバージョンは上書きしない。一方、不完全な初期インストールがあればmanifestの再applyを試みる。

**ライブデモ受入試験**：README 9章の「v1 v1→v2 v1→v2 v2→ドリフト復旧 v2 v2→リセット v1 v1」を2周成功させ、GitHub Actions pass・RBACを現物確認し、失敗時に提示できる画面録画または静止画を準備する。

## v4追記：完全初回セットアップの確認

- `mkdir -p` による作業フォルダ作成、DownloadsからのZIP確認と解凍、正しいディレクトリへの`cd`を冒頭へ追加。
- HomebrewとDocker Desktopの未導入時の公式導入コマンド・起動コマンドを追加。
- GitHub CLIから空の公開リポジトリを作成する手順を追加。
- `START_HERE.md`を追加し、ZIPダウンロード直後の導線を明示。
- `unzip -n`で上書きしない・既存GitHub mainを上書きしない原則を維持。
- 実機統合テスト（Mac、Docker、kind、GitHub）は引き続き未実施。
