# agent-skills

自作の [Agent Skills](https://agentskills.io/) を集約したリポジトリ。
複数マシン間で `gh skill`（GitHub CLI v2.90.0+）を使って配布・更新する。

## 収録スキル

| スキル | 概要 |
| --- | --- |
| `claude-actions-doctor` | Claude Code を GitHub Actions 上で動かすワークフローの点検手順 |
| `critique-panel` | 複数の批判的視点から並行レビューして統合する |
| `cve-triage` | CVE・アドバイザリの現リポジトリへの影響有無を判定する |
| `nix-add` | home-manager 管理の dotfiles に Nix パッケージを追加する |

## インストール

Claude Code のユーザースコープ（`~/.claude/skills/`、全プロジェクト共通）へ入れる場合:

```bash
# 全部まとめて
gh skill install 7crabs/agent-skills --all --agent claude-code --scope user

# 個別に選んで
gh skill install 7crabs/agent-skills nix-add --agent claude-code --scope user

# バージョン固定（tag / commit SHA）
gh skill install 7crabs/agent-skills --all --pin v1.0.0 --agent claude-code --scope user
```

一覧・プレビュー・更新:

```bash
gh skill preview 7crabs/agent-skills   # リポジトリ内のスキル一覧
gh skill list                          # インストール済み一覧
gh skill update                        # インストール済みを最新へ
```

## 構成

各スキルは `skills/<name>/SKILL.md` 規約で独立配置。補助ファイルがある場合は
同じスキルフォルダ内に `scripts/` `references/` `assets/` として置く。

```
skills/
├── claude-actions-doctor/SKILL.md
├── critique-panel/SKILL.md
├── cve-triage/SKILL.md
└── nix-add/SKILL.md
```

## メンテナンス

スキルを編集したら push 前に検証する:

```bash
gh skill publish        # agentskills.io 仕様への適合を検証
gh skill publish --fix  # 自動修正可能な項目を修正
```
