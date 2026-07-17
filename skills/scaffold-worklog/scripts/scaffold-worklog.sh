#!/usr/bin/env bash
# scaffold-worklog.sh — 意思決定ログ＋事実台帳の作業構造を生成する
#
# 「決定(DECISIONS)・事実(FACTS)・未確定(OPEN_QUESTIONS)・申し送り(log)」を積み重ね、
# 使い捨てセッションでも CLAUDE.md 起点で再開できる構造を作る。
#
# 使い方:
#   scaffold-worklog.sh --mode new      [--name "プロジェクト名"] [--dir PATH] [--force]
#   scaffold-worklog.sh --mode existing [--name "プロジェクト名"] [--dir PATH] [--force]
#   scaffold-worklog.sh                 # --mode 省略時は自動判定（git+ソースあり→existing）
#
#   new      : 知識作業向け。記録ファイルをルート直下に置き deliverables/ を作る。
#   existing : 既存コードリポジトリ向け。記録ファイルを worklog/ に隔離し、
#              ルートの CLAUDE.md に「worklog 運用」節を追記（無ければ最小版を作成）。
#
# 安全策: 既存の記録ファイルは上書きしない（--force で上書き）。冪等。

set -euo pipefail

MODE=""
NAME=""
DIR="."
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)  MODE="${2:-}"; shift 2 ;;
    --name)  NAME="${2:-}"; shift 2 ;;
    --dir)   DIR="${2:-}";  shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

cd "$DIR"
ROOT="$(pwd)"

# --- モード自動判定 -------------------------------------------------------
if [ -z "$MODE" ]; then
  if [ -d .git ] && \
     ls package.json go.mod Cargo.toml pom.xml build.gradle pyproject.toml \
        setup.py Gemfile composer.json mix.exs 2>/dev/null | grep -q . \
     || [ -d src ] || [ -d lib ] || [ -d app ]; then
    MODE="existing"
  else
    MODE="new"
  fi
fi
[ "$MODE" = "new" ] || [ "$MODE" = "existing" ] || { echo "--mode must be new|existing" >&2; exit 2; }

# --- 置換変数 -------------------------------------------------------------
[ -n "$NAME" ] || NAME="$(basename "$ROOT")"
TODAY="$(date +%F)"

if [ "$MODE" = "existing" ]; then
  BASE="$ROOT/worklog"
else
  BASE="$ROOT"
fi
mkdir -p "$BASE"

subst() { sed -e "s|{{PROJECT_NAME}}|$NAME|g" -e "s|{{DATE}}|$TODAY|g"; }

# ファイルを書く（存在すればスキップ。--force で上書き）
emit() {
  local path="$1"
  if [ -e "$path" ] && [ "$FORCE" -ne 1 ]; then
    echo "  skip (exists): ${path#$ROOT/}"
    return
  fi
  mkdir -p "$(dirname "$path")"
  subst > "$path"
  echo "  write: ${path#$ROOT/}"
}

if [ "$BASE" = "$ROOT" ]; then
  echo "scaffold-worklog: mode=$MODE  name=\"$NAME\"  base=(root)"
else
  echo "scaffold-worklog: mode=$MODE  name=\"$NAME\"  base=${BASE#$ROOT/}"
fi

# =========================================================================
# 共通の記録ファイル（new=ルート / existing=worklog/）
# =========================================================================

emit "$BASE/PLAN.md" <<'EOF'
# PLAN：フェーズ計画と状態（=再開の地図）

> 全体カレンダー（プロジェクトのフェーズ）。日々の自分の段取りは `WORKPLAN.md`。
> 方針の採否は `DECISIONS.md` / `OPEN_QUESTIONS.md` を参照。

状態の凡例：✅完了 / 🔄進行中 / ⬜未着手

| Phase | やること | 成果物 | 必要な入力 | 締切 | 状態 |
|---|---|---|---|---|---|
| **0 調査・前提把握** | 既存情報・コード・関係者ヒアリングで前提を把握 | `research/`、`FACTS.md` | — | — | ⬜ |
| **1 方針確定** | 設計/進め方をADR化 | `DECISIONS.md` | Phase0 | — | ⬜ |
| **2 実行** | 方針に沿って作る | 成果物 | Phase1 | — | ⬜ |
| **3 確定・引き渡し** | レビュー・確定・記録 | 完了記録 | Phase2 | — | ⬜ |

## 現在地
- （いま何フェーズで、次の一手は何か。新セッションはまずここを読む）

## 未確定（PLANに影響するもの）
- （→ 詳細は `OPEN_QUESTIONS.md`）
EOF

emit "$BASE/WORKPLAN.md" <<'EOF'
# WORKPLAN：私の段取り（いつまでに何を調べ・何を作る）

> `PLAN.md`=全体カレンダー（組織のフェーズ）／**これ=自分の実行ToDo**。締切から逆算した具体タスク。
> 凡例：[ ]未着手 [~]着手中 [x]完了

---

## ① 直近のゴール
**ゴール：（このスプリント/今日で何を達成すれば前進か）**
- [ ] …

## ② 次にやること（仮置き・前提が変わったら見直す）
- [ ] …
EOF

emit "$BASE/FACTS.md" <<'EOF'
# FACTS：確定事項（与件）

> 外から与えられた**事実のみ**。**私たちの決定は `DECISIONS.md`**。各項に[出所/鮮度]を付す。
> 調査(`research/`)由来でユーザー確認が取れたものだけここへ昇格。**事実が変わったら該当の決定(DECISIONS)を見直す。**
> （コードリポジトリの場合：コード現物とgit履歴も一次情報。ただし「読んで確認した事実」だけをここに書く。）

## 制度・前提
- （例）… [出所 / 確認日]

## 関係者・体制
- …

## 制約・締切
- …
EOF

emit "$BASE/DECISIONS.md" <<'EOF'
# DECISIONS：方針記録（ADRログ）

> 私たちが**合意した**方針のみ。私の提案で未合意のものは `OPEN_QUESTIONS.md` へ。
> 前提となる事実は `FACTS.md`。**事実が変わったら該当ADRを見直す。**
> フォーマット：ADR-NNN / 日付 / 背景 / 決定 / 根拠 / 影響。

---

## ★北極星（最上位の原則）：（このプロジェクトで絶対に守りたい一行）
- **日付**：{{DATE}}
- **原則**：（判断に迷ったとき、どちらへ倒すかを決める上位の意図）
- **判断に迷ったら**：…

---

## ADR-001：（決定の見出し）
- **日付**：{{DATE}}（合意状況：未合意なら OPEN_QUESTIONS へ）
- **背景**：…
- **決定**：…
- **根拠**：…
- **影響**：…
EOF

emit "$BASE/OPEN_QUESTIONS.md" <<'EOF'
# OPEN_QUESTIONS：未確定・確認待ち

> 解決したら `FACTS.md`（事実）または `DECISIONS.md`（決定）へ昇格し、ここから消す。
> 状態：🟥未着手 / 🟨相手待ち / 🟩解決(昇格待ち)

## 方針の採否（私の提案・未合意）
> いずれも提案段階。**合意を得てから** DECISIONS へ昇格する。
- 🟥 …

## 確認待ち（事実）
- 🟥 …
EOF

# research/ と log/ は雛形 + .gitkeep
emit "$BASE/log/_TEMPLATE.md" <<'EOF'
# {{DATE}}_（セッション/MTG名）

## 何をしたか
- …

## 決まったこと → DECISIONS / FACTS へ反映
- …

## 残った論点 → OPEN_QUESTIONS へ
- …

## 次セッションへの申し送り（1段落）
> （次に開くセッションが、ここだけ読めば続きから動ける要約。現在地と次の一手。）
EOF

emit "$BASE/research/_TEMPLATE.md" <<'EOF'
# {{DATE}}_（調査テーマ）

> 調査結果（腐る情報）。**確認できたものだけ `FACTS.md` へ昇格**する。出所・鮮度を必ず付ける。

## 調べたこと
- …

## わかったこと（要確認）
- … [出所]

## FACTSへ昇格してよいか（要ユーザー確認）
- [ ] …
EOF

# =========================================================================
# new モード専用：deliverables/ と ルートCLAUDE.md
# =========================================================================
if [ "$MODE" = "new" ]; then
  emit "$BASE/deliverables/.gitkeep" <<'EOF'
EOF

  emit "$ROOT/CLAUDE.md" <<'EOF'
# プロジェクト：{{PROJECT_NAME}}

（このプロジェクトの目的・ゴール・期限を1〜2行で。背景は FACTS.md / log へ。）

## まず読む順番（新セッションはここから）
1. このファイル（自動読込）で全体像と現在地を把握
2. `PLAN.md`（全体カレンダー）＋ `WORKPLAN.md`（実行ToDo）… =再開の地図
3. 今のフェーズに必要なものだけ：`deliverables/` ＋ `FACTS.md` ＋ `DECISIONS.md`
   - `research/` 全文と `log/` は必要時のみ読む

## 記録ルール（どこに何を書くか）
| ファイル | 役割 |
|---|---|
| `FACTS.md` | 外から与えられた**確定事項（与件）**。出所・鮮度を必ず付ける。 |
| `DECISIONS.md` | 私たちが**決めた方針（ADR）**。連番・背景・決定・根拠。 |
| `OPEN_QUESTIONS.md` | **未確定・確認待ち**。解決したらFACTS/DECISIONSへ昇格。 |
| `research/` | **調査結果（腐る情報）**。確認できたものだけFACTSへ昇格。 |
| `log/` | MTG/セッションの生記録。末尾に「次セッションへの申し送り」。 |
| `deliverables/` | 提出物・成果物。 |
| `WORKPLAN.md` | **私の実行ToDo**（いつまでに何を調べ・何を作る）。PLAN=全体カレンダーとは別。 |

## 再開プロトコル（セッションを使い捨てにする）
- **開始時**：CLAUDE.md（自動）→ `PLAN.md`（現在フェーズ）→ 必要ファイルだけ読む。
- **終了時（トピック完了＝セッションの区切り）**：`PLAN.md`の状態更新／新与件→`FACTS.md`／決定→`DECISIONS.md`／残論点→`OPEN_QUESTIONS.md`／`log/`に申し送り1段落。
- 1トピック終わったら**新セッションを開き、CLAUDE.md起点で続きから**。

## 鉄則
- コンテキスト肥大を避けるため、**過去調査を再実行しない**。`FACTS`/`DECISIONS`を正とする。
- **事実(FACTS)と決定(DECISIONS)を混ぜない**。事実が変われば決定の前提を見直す。
- このCLAUDE.mdは毎セッション読み込まれる。**薄く保つ**（詳細は各ファイルへ）。
- **research(外部由来)はユーザー確認まで判断の根拠にしない**。機微情報は能動的に集めない／一覧化しない。
- **私の提案を勝手に決定(DECISIONS)に昇格しない**。合意を得てから昇格する。
EOF
fi

# =========================================================================
# existing モード専用：ルートCLAUDE.md に worklog 運用節を追記
# =========================================================================
if [ "$MODE" = "existing" ]; then
  emit "$BASE/log/.gitkeep" <<'EOF'
EOF
  emit "$BASE/research/.gitkeep" <<'EOF'
EOF

  MARKER="<!-- worklog-protocol -->"
  SNIPPET="$BASE/.worklog-claude-snippet.md"
  subst > "$SNIPPET" <<'EOF'
<!-- worklog-protocol -->
## 作業記録（worklog/）の運用 — 意思決定と事実の積み重ね

このリポジトリでの調査・決定・申し送りは `worklog/` に蓄積する。**新セッションはまず `worklog/PLAN.md` の「現在地」を読む。**

| ファイル | 役割 |
|---|---|
| `worklog/FACTS.md` | 確認できた**事実（与件）**。出所・鮮度付き。**コード現物とgit履歴も一次情報**だが、読んで確認した事実だけ書く。 |
| `worklog/DECISIONS.md` | **合意した方針（ADR）**。連番・背景・決定・根拠。 |
| `worklog/OPEN_QUESTIONS.md` | **未確定・確認待ち**。解決したらFACTS/DECISIONSへ昇格。 |
| `worklog/PLAN.md` / `worklog/WORKPLAN.md` | 全体フェーズ / 実行ToDo。 |
| `worklog/research/` `worklog/log/` | 調査メモ / セッション申し送り。 |

**鉄則**：①過去調査を再実行せず `FACTS`/`DECISIONS` を正とする ②事実と決定を混ぜない ③提案を勝手にDECISIONSへ昇格しない（合意後に昇格） ④終了時に PLAN更新・新事実→FACTS・決定→DECISIONS・残論点→OPEN_QUESTIONS・`log/` に申し送り1段落。
EOF

  if [ -f "$ROOT/CLAUDE.md" ]; then
    if grep -qF "$MARKER" "$ROOT/CLAUDE.md"; then
      echo "  skip (CLAUDE.md already has worklog protocol)"
    else
      printf '\n' >> "$ROOT/CLAUDE.md"
      cat "$SNIPPET" >> "$ROOT/CLAUDE.md"
      echo "  append: CLAUDE.md (worklog protocol section)"
    fi
  else
    {
      echo "# $NAME"
      echo
      echo "（このリポジトリの概要。ビルド/テスト等は \`/init\` で追記推奨。）"
      echo
      cat "$SNIPPET"
    } > "$ROOT/CLAUDE.md"
    echo "  write: CLAUDE.md (new, minimal)"
  fi
  rm -f "$SNIPPET"

  echo
  echo "ヒント: worklog/ をチームと共有しないなら、.gitignore に 'worklog/' を追加。"
fi

echo "done."
