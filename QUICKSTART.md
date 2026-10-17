# FlowBase デモ・クイックスタート v4（Mac）

この手順は**ZIPをダウンロードした直後**から開始できます。①以降は作業フォルダで実行します。必要なツールの導入とGitHubリポジトリ作成も含みます。

## ⓪ Macの作業フォルダを作成し、ZIPを解凍する（ここから開始）

1. この手順書と一緒に配布した **`flowbase-argocd-demo-v4.2.zip`** をダウンロードする。通常はMacの `~/Downloads` に保存されます。
2. Macの「ターミナル」を開き、**以下を先頭から実行**してください。`/path/to/...` の置換は不要です。

```bash
# ホームディレクトリに作業用フォルダを作成
mkdir -p "$HOME/Projects"

# ZIPがあることを確認して解凍。既存ファイルは上書きしない
if [ -f "$HOME/Downloads/flowbase-argocd-demo-v4.2.zip" ]; then
  unzip -n -q "$HOME/Downloads/flowbase-argocd-demo-v4.2.zip" -d "$HOME/Projects"

  # 作業フォルダへ移動して、正しい場所か確認
  if cd "$HOME/Projects/flowbase-argocd-demo-v4.2" && test -f scripts/bootstrap.sh; then
    chmod +x scripts/*.sh
    pwd
    echo '[PASS] 作業フォルダとスクリプトを確認'
  else
    echo '[FAIL] 解凍先を確認してください。'
  fi
else
  echo '[FAIL] ZIPが ~/Downloads にありません。ダウンロード先を確認してください。'
fi
```

**成功条件:** 最後に `[PASS] 作業フォルダとスクリプトを確認` と表示され、`pwd` が `.../Projects/flowbase-argocd-demo-v4.2` で終わること。
ZIPを別の場所に保存した場合は、`$HOME/Downloads/flowbase-argocd-demo-v4.2.zip` の部分だけ実際のパスに変更します。フォルダ自体をFinderで手動作成する必要はありません。

**Homebrew未導入の場合だけ：** [Homebrew公式サイト](https://brew.sh/ja/)の案内に従い、以下を実行。インストール時に表示される `brew shellenv` の案内に従ってPATHを設定してください（Apple Silicon Macでは通常 `/opt/homebrew/bin/brew`）。

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Apple SiliconでbrewがPATHにない場合
if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
brew --version
```

**Docker Desktop未導入の場合だけ：** 次のコマンドでインストールできます。初回起動時は画面上で使用許諾と初期設定を完了してください。

```bash
brew install --cask docker-desktop
open -a Docker
```

すでにDocker Desktopがある場合は `open -a Docker` だけ実行します。`docker info` にエラーが出なくなるまで、Docker Desktopの起動を確認してください。

---

## ① ツールの準備と環境構築

以後のコマンドは、⓪で移動した**作業フォルダ内**で実行します。新しいターミナルを開いた場合は `cd "$HOME/Projects/flowbase-argocd-demo-v4.2"` で戻ってください。

```bash
# Docker Desktopが起動していることを確認（事前に open -a Docker）
docker info >/dev/null && echo '[PASS] Dockerが起動しています'

# 不足しているものもまとめてインストール（既存ツールは保持される）
brew install kind kubectl helm argocd gh python git

# 必要なコマンド・Dockerを点検して、環境を構築
./scripts/check.sh tools
./scripts/bootstrap.sh

# セットアップ後のチェック（bootstrap内でも自動実行）
./scripts/check.sh cluster
./scripts/check.sh argocd
```

**成功条件:** 末尾に `PASS: infrastructure is ready.`、各チェックに `[PASS]` が出ること。失敗した工程があれば、エラーを確認・修正して同じコマンドから再開できます。クラスタは勝手に削除しません。

## ①.5 セキュリティ：公開前のGitコミットIDを保護

初回push前に **[SECURITY.md](SECURITY.md)** を確認。特にrepo-localのGitメールをnoreplyに変更します（必要な認証: `gh auth login`）。

```bash
gh auth status || gh auth login
gh auth setup-git
if [ ! -d .git ]; then git init -b main; fi
git config --local user.name "$(gh api user --jq .login)"
git config --local user.email "$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
git config --local --get user.email
```

`connect-github.sh`は配布ファイルのみをコミットし、Secrets・公開不要の文脈の静的検査に合格しない場合はpushを止めます。ただしヒューリスティック検査のため、重要情報の確認は人手でも必要です。

## ② GitHub接続（初回）

GitHub CLIを初回認証します。これで**空の公開リポジトリをCLIから作成**できるため、ブラウザで手作業する必要はありません。既存の同名リポジトリがあれば上書きせず、接続先として利用します（中身が違う場合は安全停止します）。

```bash
# 認証済みであれば対話ログインはスキップ
gh auth status || gh auth login
gh auth setup-git

# GitHubアカウント名を取得して、未作成なら公開リポジトリを作成
GITHUB_USER="$(gh api user --jq .login)"
if ! gh repo view "$GITHUB_USER/flowbase-argocd-demo" >/dev/null 2>&1; then
  gh repo create "$GITHUB_USER/flowbase-argocd-demo" --public
fi

# pushに使うGitの名前/メールの設定を点検。失敗時は詳細READMEを参照
git var GIT_AUTHOR_IDENT

# 初期push、AppProject、Application登録、確認を一括実行
export REPO_URL="https://github.com/${GITHUB_USER}/flowbase-argocd-demo.git"
./scripts/connect-github.sh "$REPO_URL"
# 上のコマンドは公開前チェックを実施し、ファイル一覧を表示して安全停止します。
# 内容を確認したら、公開を明示的に承認して初期pushします。
CONFIRM_PUBLIC_PUSH=YES ./scripts/connect-github.sh "$REPO_URL"
./scripts/check.sh apps
```

**成功条件:** `[PASS] Application definitions are registered`。GitHub Actionsの初回CIが成功したかはGitHubの画面で別途確認してください。

**初期pushの直後・PR作成の前**に、GitHub Settings > Rules > Rulesets でmainへのPRとCIを必須にしてください（[SECURITY.md](SECURITY.md)参照）。ご自身だけで運用する場合、第三者レビューの承認があったとは説明しないでください。

## ③ GUI起動と最初のSync

別ターミナルで `./scripts/start-ui.sh` を起動し、**開いたまま**にする。https://localhost:8080 でadminログイン。初期パスワード：

```bash
argocd admin initial-password -n argocd
```

GUIで `flowbase-staging`と`flowbase-prod`をそれぞれ**手動SYNC**。その後：

```bash
./scripts/check.sh v1 v1
```

**PASSにならない限り次へ進まない**。アプリは http://localhost:8082 （Staging）、http://localhost:8081 （Prod）。

## ④ リリース用PRを事前準備

```bash
./scripts/release-staging-v2.sh && ./scripts/release-prod-v2.sh
```

GitHub上に**OpenのPRが2つ**・CI成功であることを確認。**まだmergeしない**。必要なら`./scripts/configure-demo-user.sh`で開発者用Argo CDユーザーを設定し、当該ユーザーでCLIログインして`./scripts/check-rbac.sh`を実行（詳細README）。

## ⑤ デモ本番の操作と検証

| 操作 | 終えたら実行するチェック |
|---|---|
| Staging PRをmerge → Argo CD StagingでRefresh→Diff→**SYNC** | `./scripts/after-merge.sh && ./scripts/check.sh v2 v1` |
| Prod PRをmerge → Argo CD ProdでRefresh→Diff→**SYNC** | `./scripts/after-merge.sh && ./scripts/check.sh v2 v2` |
| `./scripts/drift-image.sh` → Argo CD ProdでRefresh→Diff→**SYNC** | `./scripts/check.sh v2 v2` |
| `./scripts/reset-v1.sh` → reset PRをmerge → GUIで両方**SYNC** | `./scripts/after-merge.sh && ./scripts/check.sh v1 v1` |

**一発診断用**：`./scripts/check.sh tools`、`./scripts/check.sh cluster`、`./scripts/check.sh argocd`、`./scripts/check.sh apps`。検証コマンドは状態反映やHTTPの起動を待ち、異常時は`[FAIL]`で止まる。Argo CDのGUI操作を自動化しないのは意図的。

**重要**：GitHubのPR/CIと権限移譲自体はArgo CDの効果ではない。Argo CDが担うのはDiff、手動Sync、Git/実環境の状態可視化。単一開発者によるPRを「第三者承認済み」とは説明しない。

詳細なエラー対応・セキュリティ・再リハーサル条件は[README.md](README.md)、実演順は[DEMO_SCRIPT.md](DEMO_SCRIPT.md)を参照。


---

**v4.1 hotfix:** Python環境混在によるGitフローテスト失敗を修正しました。原因・既存v4フォルダへの修正手順は[HOTFIX.md](HOTFIX.md)を参照してください。
