# agent-skills

自作の [Agent Skills](https://agentskills.io/) を集約したリポジトリ（**public**。業務固有の情報は書かない）。
複数マシン間で `gh skill`（GitHub CLI）を使って配布・更新する。

> **注意:** `gh skill` は preview 機能で、フラグや既定動作は予告なく変わり得る。
> 以下のコマンドは **gh 2.96.0 / 2026-07 時点**で動作確認したもの。
> 挙動が食い違う場合は末尾の[参照先](#参照先-一次情報)（一次情報）を優先すること。

## 収録スキル

| スキル | 概要 |
| --- | --- |
| `audience-writing` | 他者向け成果物で想定読者を確定し、セッション内文脈を読者に漏らさない執筆原則 |
| `claude-actions-doctor` | Claude Code を GitHub Actions 上で動かすワークフローの点検手順 |
| `critique-panel` | 複数の批判的視点から並行レビューして統合する |
| `cve-triage` | CVE・アドバイザリの現リポジトリへの影響有無を判定する |
| `nix-add` | home-manager 管理の dotfiles に Nix パッケージを追加する |
| `scaffold-worklog` | 意思決定ログ＋事実台帳(FACTS/DECISIONS/OPEN_QUESTIONS/log)の作業構造を生成する |
| `talk-design` | 勉強会・発表の筋（聞き手・答える問い・持ち帰り・問いの連鎖）をスライド作成前に段階的に設計する |
| `tech-research` | 技術調査を、観点の抜け漏れと「未確認なのに断言」を防ぐ規律に沿って実施する |

## 新しいPCでのセットアップ

1. GitHub CLI を用意（未認証なら `gh auth login`）。
2. Claude Code のユーザースコープ（`~/.claude/skills/`、全プロジェクト共通）へ、
   **タグを明示（`--pin`）して**インストールする:

   ```bash
   gh skill install 7crabs/agent-skills --all --pin v0.1.0 --agent claude-code --scope user --force
   ```

3. 版を確認:

   ```bash
   gh skill list --scope user --json skillName,version,pinned \
     --jq '.[]|select(.pinned)|"\(.skillName)\t\(.version)"'
   ```

個別に入れる場合は `--all` の代わりにスキル名を指定:

```bash
gh skill install 7crabs/agent-skills nix-add --pin v0.1.0 --agent claude-code --scope user
```

> **なぜ必ず `--pin` するか:** 無指定 install はタグを無視して main HEAD を使い、
> `version=main` になって「各PCが今どの版か」が曖昧になる。`--pin vX.Y.Z` を付けると
> `gh skill list` の version 列にタグが出て、PC間の版の取り違えを防げる。

## バージョン管理

「どのPCがどの版か」を明確に保つため、**リリースは git tag で区切り、install は必ず `--pin`** する。

```bash
# 新版を出す（母艦PCで）
cd ~/projects/agent-skills
# ...編集して commit...
git tag v0.2.0 && git push --tags

# 各PCを新版へ上げる（--pin した skill は gh skill update の対象外なので再install で移動）
gh skill install 7crabs/agent-skills --all --pin v0.2.0 --agent claude-code --scope user --force
```

- `--pin` した skill は `gh skill update` からスキップされる。`--unpin` で pin を解除できる。
- 現在の最新タグ: `v0.6.0`

## 構成

各スキルは `skills/<name>/SKILL.md` 規約で独立配置。補助ファイルがある場合は
同じスキルフォルダ内に `scripts/` `references/` `assets/` として置く。

```
skills/
├── claude-actions-doctor/SKILL.md
├── critique-panel/SKILL.md
├── cve-triage/SKILL.md
├── nix-add/SKILL.md
├── scaffold-worklog/
│   ├── SKILL.md
│   ├── README.md
│   └── scripts/scaffold-worklog.sh
└── tech-research/SKILL.md
```

## メンテナンス

スキルを編集したら push 前に検証する:

```bash
gh skill publish        # agentskills.io 仕様への適合を検証
gh skill publish --fix  # 自動修正可能な項目を修正
```

## 参照先 (一次情報)

preview 機能のため、コマンドや挙動が本 README と食い違ったら以下を正とする:

- [Agent Skills 仕様](https://agentskills.io/specification) — SKILL.md の frontmatter・ディレクトリ規約
- [`gh skill install` マニュアル](https://cli.github.com/manual/gh_skill_install) — フラグとバージョン解決の挙動
- [GitHub Changelog: Manage agent skills with GitHub CLI](https://github.blog/changelog/2026-04-16-manage-agent-skills-with-github-cli/)
- 手元での確認: `gh skill --help` / `gh skill install --help` / `gh skill update --help`
