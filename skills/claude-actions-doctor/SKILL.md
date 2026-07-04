---
name: claude-actions-doctor
description: Claude Code を GitHub Actions 上で動かすワークフローの新規セットアップ時、または実行が失敗・スキップされたときの点検手順。過去に実際にハマった項目のチェックリスト。
---

# Claude GitHub Actions 健全性チェック

まず対象ワークフローがどちらの構成か確認する（両方混在することもある）:
- **[A] 公式アクション**: `anthropics/claude-code-action` を uses で呼ぶ
- **[B] CLI直叩き**: run ステップで `claude` コマンドを直接実行する

## チェックリスト
1. **[共通] permissions**: ジョブに `id-token: write` があるか（`contents: write` / `pull-requests: write` も用途に応じて）
2. **[共通] Claude GitHub App**: 対象リポジトリにインストール済みか。確認は `gh api /user/installations` で自分がアクセス可能なインストール一覧を見る（`/repos/{owner}/{repo}/installation` はApp認証専用で、ユーザートークンでは**インストール済みでも401になる**ので使わない）。実行ログに "Claude GitHub App is not installed" が出ていないかも見る
3. **[共通] 認証**: サブスク消化なら `CLAUDE_CODE_OAUTH_TOKEN` シークレットが設定されているか（API従量課金を避ける場合）。失効していたらローカルで `claude setup-token` を再実行して差し替える
4. **[B] ヘッドレス実行**: `--dangerously-skip-permissions` が付いているか（付けないと権限プロンプトで停止する）。[A]では `claude_args` 経由で渡す
5. **[共通] --max-turns**: タスク規模に対して十分か（途中打ち切りの典型原因）
6. **[B] post-stepのgit push**: リモートURLに認証を埋め込んでいるか（`https://x-access-token:${GH_TOKEN}@github.com/...`。GH_TOKEN はワークフローの `secrets.GITHUB_TOKEN`。ジョブに `contents: write` が必要）
7. **[共通] スキップ条件**: ワークフロー自身の条件分岐（未処理ファイルの有無判定など）で意図せずスキップされていないか

## デバッグ手順
- `gh run list --workflow=<name>` → `gh run view <id> --log-failed` で失敗ログを読む
- 手動トリガーは `gh workflow run <name> -f force=true` → `gh run watch`
- 成果物の確認: `gh pr list` → `git pull` → 生成物のパスを find
