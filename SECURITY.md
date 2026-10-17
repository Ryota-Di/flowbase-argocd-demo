# SECURITY｜Publicデモの実施条件（v4.2）

このリポジトリは **架空企業のダミー画面専用** です。業務データ、実在顧客情報、会社の機密、個人の記録、APIトークンを含めないでください。Publicで公開する必要がなければPrivate＋読み取り専用Git認証を検討してください（本パッケージのワンコマンド構築はPublic前提）。

## 1. GitHubへ初めてpushする前の必須作業

ローカル作業フォルダで実行（GitHub CLIログインが必要）：

```bash
gh auth status || gh auth login
gh auth setup-git
if [ ! -d .git ]; then git init -b main; fi
git config --local user.name "$(gh api user --jq .login)"
git config --local user.email "$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
```

GitHub設定 > Emails でプライベートメールの保護を有効にすること。設定直後は `git config --local --get user.email` の末尾が `@users.noreply.github.com` であることを確認してください。

`./scripts/connect-github.sh "$REPO_URL"` は配布済みファイルのみステージし、漏洩検査後に**公開前で安全停止**します。公開対象をレビューしたあと `CONFIRM_PUBLIC_PUSH=YES ./scripts/connect-github.sh "$REPO_URL"` と明示すると初期コミットとpushを行います。検査はパターンマッチであり完全な保証ではありません。公開前に `git show --stat --oneline HEAD` で対象を確認してください。

## 2. GitHubルールセット

最初のcommit/pushが済んだら、GitHubの Settings > Rules > Rulesets で `main` 向けに次を設定：
- Require a pull request before merging
- Require status checks to pass（初回CI成功後に `helm-and-shell` を選ぶ）
- Block force pushes and branch deletion

単独運用では別人のレビュー承認を実際には示せません。見せかけの承認済みとは説明しないこと。ブランチ保護が有効になれば `reset-v1.sh --direct-demo-only` は使わずPR経由にすること。

## 3. Argo CD管理者アカウント

GUIのport-forwardを有効にした後、CLIで一度だけ行う：

```bash
argocd login localhost:8080 --username admin --insecure
argocd account update-password
kubectl -n argocd delete secret argocd-initial-admin-secret
```

`--insecure` はこのローカル自己署名証明書の検証をスキップするためであり、公衆ネットワークや実運用環境では使用しない。secret削除はパスワード変更が成功した後のみ。

RBACの`demo-developer`はStaging/Prodアプリ2件の閲覧・手動Syncに限定し、`./scripts/check-rbac.sh`で許可・拒否を実測。AppProjectは対象リポジトリ、Namespace、リソース種別を限定しているがArgo CDコントローラ自身のKubernetes権限を縮小しているわけではない。

## 4. リスクと制約

- Argo CD公式 `stable` マニフェスト、GitHub Actionsのタグ、`nginx:stable-alpine` は不変ではない。厳密な再現・供給網対策にはバージョンやSHA/digest固定を要する。
- `kind` NodePort 8081/8082 とArgo CD 8080はホストループバックに限定する。VPN共有やポート開放、公開クラウドへのインストールは想定外。
- GitHub Actionsは `contents: read` だけを要求し、Actions Secretsを設定しない。外部からのPRは信用せず、コードを検証する際にCIで実行する内容を見直す。
- 公開したコード・Git履歴は後からPrivateにしても既存クローンやフォークから消えるとは限らない。
