# 最初にここを読む（Mac）

**ダウンロードしたZIPから開始する構築ガイド**です。`QUICKSTART.md` の⓪から順番に実行してください。

- [QUICKSTART.md](QUICKSTART.md) : 作業フォルダ作成・解凍→ツール導入→クラスタ→GitHub→GUI→デモ
- [README.md](README.md) : 失敗した場合の対処、各操作の理由、技術的な注意点
- [DEMO_SCRIPT.md](DEMO_SCRIPT.md) : プレゼン本番の17分間の台本
- [REVIEW.md](REVIEW.md) : 静的検証状況と実機テストの留保

## 最初のコマンドだけ抜粋

```bash
mkdir -p "$HOME/Projects"
unzip -n -q "$HOME/Downloads/flowbase-argocd-demo-v4.2.zip" -d "$HOME/Projects"
cd "$HOME/Projects/flowbase-argocd-demo-v4.2"
chmod +x scripts/*.sh
pwd
test -f scripts/bootstrap.sh && echo '[PASS] Ready to start'
```

既に同じフォルダへ解凍した場合でも、`unzip -n`なので既存ファイルを上書きしません。Downloads以外へZIPを保存した場合はパスを置き換えてください。

## 初回pushの安全対策（必読）

[SECURITY.md](SECURITY.md)を確認してください。作業フォルダ内で `gh auth status || gh auth login` 後、repo-localの `user.email` をGitHub `noreply` に設定してから、修正版 `scripts/connect-github.sh` を実行してください。Publicへの初回コミットでは、配布ファイルのみをステージし、機密パターンのチェックに合格しなければ停止します。
