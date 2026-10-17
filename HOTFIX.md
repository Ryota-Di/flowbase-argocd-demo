# v4.1 hotfix — Python環境の混在

v4 の `tests/git_flow_checks.py` は `.venv` から起動されても、内部で `python3 tests/static_checks.py` を実行していました。Homebrew Python のグローバル環境に PyYAML がない場合、Gitフローテストが失敗し、`bootstrap.sh` がクラスタ作成前に停止します。

修正版は `sys.executable` を使い、親テストと同じPythonを使用します。また子プロセスの失敗内容を表示します。

すでに v4 を Mac に展開している場合、ZIPを再解凍する必要はありません。以下を実行してください。

```bash
cd "$HOME/Projects/flowbase-argocd-demo-v4"
python3 - <<'PYCODE'
from pathlib import Path
p = Path('tests/git_flow_checks.py')
s = p.read_text()
a = 'import subprocess\n'
b = 'cmd(repo, "python3", "tests/static_checks.py")'
if b not in s:
    print('[SKIP] 修正対象が見つかりません。既に修正済みか内容を確認してください。')
else:
    s = s.replace(a, a + 'import sys\n', 1) if 'import sys\n' not in s else s
    s = s.replace(b, 'cmd(repo, sys.executable, "tests/static_checks.py")', 1)
    p.write_text(s)
    print('[PASS] Python実行環境を統一しました')
PYCODE
./scripts/local-tests.sh && ./scripts/bootstrap.sh && ./scripts/check.sh cluster && ./scripts/check.sh argocd
```

上記の「クラスタのcontextが空」は、オフラインテストが失敗した時点でクラスタ作成へ進めなかったことによる二次的なメッセージです。kindクラスタの削除、contextの強制変更、グローバルPythonへのPyYAML導入は不要です。
