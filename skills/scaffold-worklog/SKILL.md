---
name: scaffold-worklog
description: 意思決定ログ＋事実台帳(FACTS/DECISIONS/OPEN_QUESTIONS/log)の作業構造を生成する。ユーザーが「作業ログの構造を作って」「worklog を初期化して」等を依頼したとき、または新しい調査・企画プロジェクトのディレクトリを立ち上げるときに使う。
argument-hint: "[new|existing] [プロジェクト名]"
allowed-tools: Bash(~/.claude/skills/scaffold-worklog/scripts/scaffold-worklog.sh:*), Read, Edit
---

カレントディレクトリに「意思決定ログ＋事実台帳」の作業構造を作る。引数: `$ARGUMENTS`（任意。`new` か `existing`、続けてプロジェクト名）。

手順:

1. **モード決定**:
   - 引数で `new` / `existing` が指定されていればそれを使う。
   - 未指定なら自動判定: `.git` があり、かつ `package.json`/`go.mod`/`Cargo.toml`/`pom.xml`/`pyproject.toml` 等のビルド定義か `src`・`app`・`lib` ディレクトリがあれば **existing**（既存コードリポジトリ → 記録は `worklog/` に隔離）、なければ **new**（知識作業 → ルート直下＋`deliverables/`）。
   - どちらか曖昧なら、判定結果を述べた上でユーザーに一言確認してから進む。

2. **スクリプト実行**: `~/.claude/skills/scaffold-worklog/scripts/scaffold-worklog.sh --mode <判定結果> [--name "<プロジェクト名>"]` を実行する。
   - 既存ファイルは上書きされない（冪等）。再実行は安全。

3. **生成後の最小カスタマイズ**（ここだけ手で埋める）:
   - **CLAUDE.md** 冒頭: プロジェクトの目的・ゴール・期限を1〜2行で。existing の場合は `<!-- worklog-protocol -->` 節が追記済みなので、その上のビルド/テスト情報が薄ければ `/init` を勧める。
   - **PLAN.md** の「現在地」と Phase 行、**DECISIONS.md** の「★北極星」を、分かっている範囲でユーザーと相談しながら埋める。空欄プレースホルダのまま放置しない。

4. 生成したファイル一覧と、次に着手すべき1ファイル（通常は PLAN.md の現在地）を簡潔に報告する。

注意: テンプレ本文を勝手に大きく書き換えない。骨格（FACTS=事実 / DECISIONS=決定 / OPEN_QUESTIONS=未確定 の分離、再開プロトコル、鉄則）は維持する。
