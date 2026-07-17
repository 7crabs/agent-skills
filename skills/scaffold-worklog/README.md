# scaffold-worklog

「意思決定ログ＋事実台帳」の作業構造を生成する Claude Code skill。使い捨てセッションでも CLAUDE.md 起点で再開できるよう、決定(DECISIONS)・事実(FACTS)・未確定(OPEN_QUESTIONS)・申し送り(log) を積み重ねる構造を作る。

## 中身
- `SKILL.md` — skill 本体（`/scaffold-worklog` で呼べる。モード判定と生成後カスタマイズの手順）。
- `scaffold-worklog.sh` — 自己完結スクリプト（テンプレ本文をヒアドキュメントで内蔵。依存なし・冪等・既存ファイルは上書きしない）。

## 設計
| | new（知識作業） | existing（既存コードリポジトリ） |
|---|---|---|
| 置き場所 | ルート直下 | `worklog/` サブフォルダに隔離 |
| CLAUDE.md | 新規作成 | 既存に `<!-- worklog-protocol -->` 節を追記（無ければ最小版を作成） |
| 成果物 | `deliverables/` | ソースコード本体（ADRは必要に応じ `docs/adr/`） |

共通のコア5ファイル: `FACTS.md`（事実=与件）/ `DECISIONS.md`（決定=ADR）/ `OPEN_QUESTIONS.md`（未確定）/ `PLAN.md`・`WORKPLAN.md`（計画）/ `research/`・`log/`。

## 使い方
```sh
# Claude Code 内
/scaffold-worklog                 # モード自動判定
/scaffold-worklog new 企画名
/scaffold-worklog existing

# 直接
~/.claude/skills/scaffold-worklog/scripts/scaffold-worklog.sh --mode new --name "企画名"
~/.claude/skills/scaffold-worklog/scripts/scaffold-worklog.sh --dir /path/to/repo   # mode自動判定
```

## テンプレ本文を直したいとき
`scaffold-worklog.sh` 内の各 `emit ... <<'EOF' ... EOF` ブロックを編集する。
置換変数は `{{PROJECT_NAME}}` と `{{DATE}}` の2つ。
