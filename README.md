# FlowBase Argo CD デモ構築ガイド v4（Mac / 実行しやすさ重視）

**目的**: 10/21の提案デモで、Gitの承認済み変更 → Argo CDでDiff → 開発者による**手動Sync** → Gitと実環境のドリフト検出・是正を示す。  
**ローカル構成**: Docker Desktop + kind (Kubernetes) + Argo CD + 公開GitHubリポジトリ + Helm。  
**最初に読む**: [QUICKSTART.md](QUICKSTART.md) に「順番に実行するだけ」の短縮版を用意。本書は理由、成功条件、復旧方法も記載。

> **Publicへの初回push前に必ず [SECURITY.md](SECURITY.md) を参照してください。** 本版ではステージ対象ファイルとnoreplyメールアドレスを自動検査します。

> **範囲と注意**: Staging/Productionはいずれも同じローカルクラスタ上の疑似環境。表示ページは決済しないUIモック。CIはHelm等の静的検査でありアプリのビルド・単体テストではない。独立したGitHub PR承認は別レビュアーとルール設定なしには再現できない。RBACなど本番の完全なセキュリティを実証しない。

## 全体の流れ（まとめたコマンドと確認ポイント）

| 順番 | すること | コマンド・操作 | 完了判定 |
|---|---|---|---|
| 0 | **作業フォルダ作成・ZIP解凍・移動** | `mkdir -p "$HOME/Projects"` → `unzip ...` → `cd ...`（下記「0.」参照） | `test -f scripts/bootstrap.sh` |
| 0.5 | ツールを導入・Docker起動 | `brew install kind kubectl helm argocd gh python git` | `./scripts/check.sh tools` |
| 1 | ローカル検査・kind作成・Argo CD導入 | `./scripts/bootstrap.sh` | 内部で `local-tests.sh`、`check.sh cluster/argocd` を自動実行 |
| 2 | GitHubへ初期Push・AppProject/Application登録 | `./scripts/connect-github.sh "$REPO_URL"
# ファイルリストと検査結果を確認し、初回公開を許可するときだけ：
CONFIRM_PUBLIC_PUSH=YES ./scripts/connect-github.sh "$REPO_URL"` | 内部で `check.sh apps` を自動実行 |
| 3 | GUI起動・初回手動Sync | 別ターミナルで `./scripts/start-ui.sh`、GUIで両アプリSync | `./scripts/check.sh v1 v1` |
| 4 | リリース用PRを2本準備 | `./scripts/release-staging-v2.sh && ./scripts/release-prod-v2.sh` | GitHubでPRチェック成功・Openを確認 |
| 5 | Staging PRのmerge→GUIでDiff/Sync | `./scripts/after-merge.sh` | `./scripts/check.sh v2 v1` |
| 6 | Production PRのmerge→GUIでDiff/Sync | `./scripts/after-merge.sh` | `./scripts/check.sh v2 v2` |
| 7 | ドリフト導入→GUIでDiff/Sync | `./scripts/drift-image.sh` | `./scripts/check.sh v2 v2` |
| 8 | v1へリセット・再準備 | `./scripts/reset-v1.sh`→PR merge→`./scripts/after-merge.sh`→GUIで2つSync | `./scripts/check.sh v1 v1` |

**ポイント**: シェルで自動化するのは環境準備・Git作業・確認まで。Argo CDの**Diffと手動Syncは意図的にGUIで行う**（提案の核心）。`./scripts/check.sh ...` は原則読み取り専用で、勝手にSyncしない。

## 0. 作業フォルダ作成から開始（初回）

**この節が最初の実行手順です。** ZIPをダウンロードしたところから実行できるようにしています。短縮版は [QUICKSTART.md](QUICKSTART.md) の⓪→①です。

```bash
mkdir -p "$HOME/Projects"
if [ -f "$HOME/Downloads/flowbase-argocd-demo-v4.2.zip" ]; then
  unzip -n -q "$HOME/Downloads/flowbase-argocd-demo-v4.2.zip" -d "$HOME/Projects"
  if cd "$HOME/Projects/flowbase-argocd-demo-v4.2" && test -f scripts/bootstrap.sh; then
    chmod +x scripts/*.sh
    pwd
    echo '[PASS] Correct project directory'
  else
    echo '[FAIL] 解凍されたフォルダを確認してください。'
  fi
else
  echo '[FAIL] ~/Downloads/flowbase-argocd-demo-v4.2.zip が見つかりません。'
fi
```

**成功条件**：`[PASS] Correct project directory` が表示され、`pwd` が `.../Projects/flowbase-argocd-demo-v4.2` となる。途中で失敗した場合はZIPの保存先と解凍先を確認する。`unzip -n`は既存ファイルを上書きしないため、繰り返し実行しても作業途中のファイルを壊さない。

MacでHomebrewが未導入の場合は、[公式インストール手順](https://brew.sh/ja/)に従って以下を実行する。Apple Siliconではインストール後に `brew shellenv` の設定が必要な場合がある。

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
brew --version
```

Docker Desktop未導入の場合は `brew install --cask docker-desktop`。導入済み/導入後は `open -a Docker` とし、初回起動の画面操作を完了する。

```bash
open -a Docker
brew install kind kubectl helm argocd gh python git
./scripts/check.sh tools
```

**成功条件**：`[PASS] required local tools and Docker`。Dockerの起動完了前に実行するとエラーになるため、Docker Desktopが起動したことを確認してから再実行する。

---

## 1. 初期セットアップ：コマンド1つ

```bash
./scripts/bootstrap.sh
```

このスクリプトが順に実行する内容：

1. 必要なコマンドとDocker起動状態の確認
2. `.venv`作成/再利用、PyYAML導入、Shell/YAML/Gitフロー/Helm lint/Helmレンダリングのオフライン検査
3. `kind-config.yaml`で `argocd-demo` クラスタ作成（既存ならポートマッピングを検証し再利用）
4. Argo CDの公式manifest導入（既存サーバーがあれば再導入しない）
5. Node Ready、8081/8082マッピング、Argo CDサーバー/リポジトリサーバー Ready、Application CRDの存在確認

**成功表示**: `[PASS] kind context, ready node, port mappings` / `[PASS] Argo CD server, repo server, Application CRD` / `PASS: infrastructure is ready.`

途中で失敗した場合は、エラーの内容を修正して**同じコマンドを再実行**する（クラスタは自動削除しない）。何が失敗したかだけを調べるには：

```bash
./scripts/check.sh cluster
./scripts/check.sh argocd
kubectl -n argocd get pods
```

**安全条件**: 操作対象のKubernetes contextは常に `kind-argocd-demo` でなければ停止する。既存の同名クラスタでポート設定が違う場合も停止する。削除が本当に必要な場合のみ、自分で `kind delete cluster --name argocd-demo` を実行する（中のデータは失われる）。

**再現性の注意**: Argo CD未導入時の既定manifestは `stable` を参照する。バージョンを固定したい場合は `ARGOCD_INSTALL_REF=vX.Y.Z ./scripts/bootstrap.sh` として、公式に存在するリリースタグを指定する。既存Argo CDはアップグレードしない。nginxサンプルのタグも将来更新され得るため、最終練習時に使った構成を保持する。

## 2. GitHub作成・初期Push・Application登録

**ブラウザで空リポジトリを作る必要はありません。** GitHub CLIの認証は初回だけ対話式です。

```bash
gh auth status || gh auth login
gh auth setup-git
if [ ! -d .git ]; then git init -b main; fi
git config --local user.name "$(gh api user --jq .login)"
git config --local user.email "$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
GITHUB_USER="$(gh api user --jq .login)"
if ! gh repo view "$GITHUB_USER/flowbase-argocd-demo" >/dev/null 2>&1; then
  gh repo create "$GITHUB_USER/flowbase-argocd-demo" --public
fi

git var GIT_AUTHOR_IDENT
export REPO_URL="https://github.com/${GITHUB_USER}/flowbase-argocd-demo.git"
./scripts/connect-github.sh "$REPO_URL"
./scripts/check.sh apps
```

**Git作者情報が未設定なら**エラーになるため、自分の情報で次を設定してから再実行する（架空のメールアドレスを入力しない）。

```bash
git config --global user.name 'GitHubに登録した表示名など'
git config --global user.email '自分のGitHub登録メールアドレス'
```

内部処理：初回のみ`git init`→v1をcommit→remote mainが空であることを確認→push→専用AppProjectと2環境Application登録→`./scripts/check.sh apps`。既存Gitリポジトリ/remoteがあれば検査して再利用。**remote mainの内容が違えば上書きせず停止**する。

**成功表示**: `[PASS] Application definitions are registered`。GitHubのmainに`charts/`、`.github/workflows/validate.yml`があり、GitHub Actionsの初回Pushチェックが成功していることもブラウザで確認。

> GitHubの認証に失敗したら `gh auth status`、`git remote -v` を確認。403の場合は書込権限を確認。`gh repo view` がネットワーク障害で失敗したときは `gh repo create` でもエラーになるので、ネットワーク復旧後に同じ工程から再開する。

## 3. Argo CD GUI起動と初回Sync

**ターミナルA（開いたまま）**:

```bash
./scripts/start-ui.sh
```

`https://localhost:8080` を開く。別ターミナルBから初期パスワード取得：

```bash
argocd admin initial-password -n argocd
```

`admin`でログインし、`flowbase-staging`と`flowbase-prod`をそれぞれ選んで **DIFF（可能なら）→ SYNC**。初期同期時はまだリソースが存在しない。**自動Sync、Force、Pruneは有効化しない**。

両方の画面が `Synced / Healthy` になったら、ターミナルBで検証：

```bash
./scripts/check.sh v1 v1
```

検証は **Staging/ProductionそれぞれのNodePort、Deploymentのrollout、イメージ、replica数、Argo CDのSynced/Healthy、HTTP応答と期待ページv1** を確認する。Argo CDの状態とHTTP表示は一定時間リトライする。成功表示は末尾の `[PASS] Both environments...`。

- Staging UI: http://localhost:8082 （v1.0／複数クリック）
- Production UI: http://localhost:8081 （v1.0／複数クリック）
- Argo CD UI: https://localhost:8080 （GUIを開く間はターミナルAのport-forwardを動かす）

**RBACの実演が必要なら**初期同期後、管理者として次を一度実行する：

```bash
./scripts/configure-demo-user.sh
argocd login localhost:8080 --username admin --insecure
argocd account update-password --account demo-developer
```

2番目・3番目は対話式で資格情報を入力する（引数にパスワードを書かない）。GUIからログアウトし`demo-developer`で再ログイン。CLIでも同じユーザーでログインし、**許可・拒否の両方**を確認：

```bash
argocd login localhost:8080 --username demo-developer --insecure
./scripts/check-rbac.sh
```

PASS条件は「Staging/Prodへのget・syncが許可」「Projectの更新・Application削除・対象外ApplicationのSyncが拒否」。adminでログインしたまま実行すると拒否テストが失敗する。RBACは**デモ専用**でSSO/本番権限構造を代替しない。GitHubレビュー権限とは別。

## 4. デモ用PRの事前準備（mergeはしない）

`gh auth login`を済ませてから、ローカルmainがGitHubのmainと一致している状態で実行：

```bash
./scripts/release-staging-v2.sh && ./scripts/release-prod-v2.sh
```

2つの独立ブランチをpushし、GitHub CLIで認証済みならPR作成まで行う。未認証なら出力されたブランチ名でGitHubから手動PR作成。**どちらのPRもOpenのまま**にし、Checksがpassしていることを確認する。Prod側はStaging動作確認**後に**mergeする。別レビュアーがいない場合、独立したPR承認を実証したと説明しない。

## 5. ライブデモ Scene 1: Staging → Production

### 5-1. Staging

1. GitHubでStaging PRのChecksと差分を見せて、PRを**merge**する。
2. ターミナルでローカルmainを更新する：

```bash
./scripts/after-merge.sh
```

3. Argo CDの`flowbase-staging`で **Refresh → OutOfSync → DIFF → SYNC**。UIで `v2.0` の1クリック動作を見せる。
4. **必ずここで確認**：

```bash
./scripts/check.sh v2 v1
```

成功条件は**Stagingのみv2、Productionは引き続きv1**。

### 5-2. Production

1. Stagingの動作確認後、GitHubでProduction PRをmerge。
2. ターミナルでローカルmainを更新する：

```bash
./scripts/after-merge.sh
```

3. Argo CDの`flowbase-prod`で **Refresh → DIFF → SYNC**。Prodでもv2の1クリック操作を見せる。
4. **必ずここで確認**：

```bash
./scripts/check.sh v2 v2
```

GitHub PR/CIはコードの変更審査・品質チェック、Argo CDは**Gitとの差分の可視化と手動同期**、権限移譲は運用設計によるもので、各効果を混同しない。

## 6. ライブデモ Scene 2: ドリフト → 差分 → 復旧

事前に **`./scripts/check.sh v2 v2` がPASS**していることを確認してから実施する。スクリプトはkind以外のcontextでは停止する。

```bash
./scripts/drift-image.sh
```

Prod Deploymentのイメージを意図的に不正タグへ変更。Argo CDの**Refresh → OutOfSync → DIFF → SYNC**でGit上の正しいイメージ定義に戻す。その後：

```bash
./scripts/check.sh v2 v2
```

※ OutOfSync検出はタイミング依存のためGUIでRefreshする。ImagePullBackOffになるかどうかはPod起動タイミングで変わる。これは**差異検出と宣言状態への同期**であり自動ロールバックの実演ではない。イメージの差分が見えにくいときの予備は`./scripts/drift-replicas.sh`。

## 7. 次の練習用リセット

**原則はPRを利用**：

```bash
./scripts/reset-v1.sh
```

GitHubでreset PRをmerge後：

```bash
./scripts/after-merge.sh
```

GUIでStagingとProdの両方を **Refresh → SYNC**。その後：

```bash
./scripts/check.sh v1 v1
```

練習を短縮したい場合だけ、**デモ専用の例外**として`./scripts/reset-v1.sh --direct-demo-only`（mainへ直接push、branch protectionが有効なら拒否される）。通常運用に使わない。リセット後は古いOpen PRを閉じて、手順4のPRを新規作成する。リセットが済んでいない状態でPRを再作成しない。

## 8. 定期的な確認・失敗時の診断

| タイミング | コマンド | 見るポイント |
|---|---|---|
| 作業開始前 | `./scripts/check.sh tools` | Dockerとローカルツール |
| kind作成後 / 再起動後 | `./scripts/check.sh cluster` | **安全なcontext・ノードReady・ポート設定** |
| Argo CD導入後 / 再起動後 | `./scripts/check.sh argocd` | Argo CDサーバー・repo-server |
| App登録直後 | `./scripts/check.sh apps` | Project・Application・namespace登録 |
| 初回Sync後 | `./scripts/check.sh v1 v1` | **実アプリとGitOps状態** |
| デモ開発者ログイン後（任意） | `./scripts/check-rbac.sh` | **操作許可だけでなく、禁止操作も拒否されるか** |
| staging反映後 | `./scripts/check.sh v2 v1` | **環境分離が保たれているか** |
| prod反映後、ドリフト復旧後 | `./scripts/check.sh v2 v2` | **両環境の状態が合っているか** |
| リセット後 | `./scripts/check.sh v1 v1` | 初期状態へ戻ったか |

**主なトラブルと対処**

| 症状 | 見るコマンド・対処 |
|---|---|
| Docker起動していない | `docker info`。Docker Desktop起動後にbootstrap再実行 |
| kube contextが違う | `kubectl config current-context`。対象がこのデモのみと確認できれば`kubectl config use-context kind-argocd-demo` |
| kind NodePortが合わない | `./scripts/check.sh cluster`、`docker port argocd-demo-control-plane`。ポート設定はクラスタ生成後に追加不可 |
| Argo CDが立ち上がらない | `kubectl -n argocd get pods`、`kubectl -n argocd describe deployment argocd-server`、`./scripts/check.sh argocd` |
| アプリ登録はあるが表示不可 | `./scripts/check.sh apps`、GUIで初回Syncしたか、`kubectl -n flowbase-staging get pod,svc` |
| Git変更を検出しない | GitHubで対象PRがmerge済みか、Argo CDのRefresh/DIFF、対象環境valuesを確認 |
| verifyがタイムアウト | `kubectl -n argocd get applications`、`kubectl -n flowbase-prod get pods`、`kubectl -n flowbase-prod describe pods`、環境別URLへの`curl -I` |
| PRが作れない | `gh auth status`、`git status`、`git remote -v`。Push済みブランチからGitHub UIで作成 |
| 8080だけ接続できない | `./scripts/start-ui.sh`のターミナルを開いたままにする。アプリ8081/8082はNodePortなので別方式 |

## 9. 最終リハーサル（ライブ実演の持ち込み条件）

- [ ] 初期: `./scripts/check.sh v1 v1` がPASS
- [ ] Staging PR merge→GUIでDiff/Sync→`./scripts/check.sh v2 v1` がPASS
- [ ] Production PR merge→GUIでDiff/Sync→`./scripts/check.sh v2 v2` がPASS
- [ ] drift-image→GUIでDiff/Sync→`./scripts/check.sh v2 v2` がPASS
- [ ] Reset PR→GUIで2環境Sync→`./scripts/check.sh v1 v1` がPASS
- [ ] 権限が適切なユーザーで操作できることを画面で確認
- [ ] GitHub CI結果、GUIでのDiff、v1/v2 UI、復旧後の状態を静止画または動画でバックアップ
- [ ] デモ操作を通しで2回再現し、流れと制限事項を説明できる

**後片付け**: ローカルデモが不要になったと自身で判断した時だけ`kind delete cluster --name argocd-demo`。GitHub repo・CLI認証は別途管理。

## 公式資料

- Argo CD Getting Started: https://argo-cd.readthedocs.io/en/stable/getting_started/
- Argo CD RBAC: https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/
- kind NodePort mapping: https://kind.sigs.k8s.io/docs/user/configuration/


---

**v4.1 hotfix:** Python環境混在によるGitフローテスト失敗を修正しました。原因・既存v4フォルダへの修正手順は[HOTFIX.md](HOTFIX.md)を参照してください。
