#!/usr/bin/env bash
# transcript.sh — Claude Code の会話記録（~/.claude/projects/<slug>/*.jsonl）から、
# カレントディレクトリで行った会話を読みやすい形で抜き出す。jq が必要。
#
# 使い方（実行権限が付かない環境があるので bash で呼ぶ）:
#   bash transcript.sh [--workdir PATH | --dir DIR] <サブコマンド>
#       --workdir PATH  この作業ディレクトリで行った会話を読む（既定はカレントディレクトリ）
#       --dir DIR       会話記録のディレクトリを直接指定する（find の結果を読むとき）
#   transcript.sh now                        現在時刻（UTC, ISO 8601）。HANDOFF.md の「最終更新」に使う
#   transcript.sh list                       このディレクトリのセッション一覧（最後の発言・タイトル・作業ディレクトリ・ID・最初の発言）
#   transcript.sh show [--since TS] [--session ID] [--user-only]
#       --since TS    この時刻（UTC, ISO 8601）より後の発言だけ
#       --session ID  このセッションだけ（既定はこのディレクトリの全セッション）
#       --user-only   ユーザーの発言だけ（既定はユーザーと Claude の本文。ツールの入出力は含めない）
#   transcript.sh recent [N]                 全ディレクトリの最近のセッション N 件（既定 20）。ユーザーに選んでもらうとき用
#   transcript.sh find TEXT                  全ディレクトリの会話記録から TEXT を含むセッションを探す
#                                            （別のディレクトリで作業してしまったとき用）

set -euo pipefail

slug() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }
DIR="$HOME/.claude/projects/$(slug "$(pwd)")"
case "${1:-}" in
  --workdir) DIR="$HOME/.claude/projects/$(slug "$(cd "${2:-}" && pwd)")"; shift 2 ;;
  --dir)     DIR="${2:-}"; shift 2 ;;
esac

cmd="${1:-}"; shift || true

if [ "$cmd" = "now" ]; then
  date -u +%Y-%m-%dT%H:%M:%SZ
  exit 0
fi

[ -d "$DIR" ] || { echo "会話記録が見つからない: $DIR（--dir で指定できる）" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq が必要" >&2; exit 1; }

# 古い順に並べた記録ファイル
files() { ls -tr "$DIR"/*.jsonl 2>/dev/null; }

# ユーザーの発言本文（スキル本文などの自動挿入・ツール結果・コマンド出力を除く）
JQ_COMMON='
def user_text:
  if (.message.content|type) == "string" then .message.content
  else ([.message.content[]? | select(.type == "text") | .text] | join("\n")) end;
def is_human:
  .type == "user" and (.isMeta | not) and (.isSidechain | not)
  and (user_text | length > 0)
  and (user_text | test("^\\s*(<command-|<local-command|<system-reminder|<task-notification|\\[Request interrupted)") | not);
def claude_text:
  [.message.content[]? | select(.type == "text") | .text] | join("\n");
def summary($u):
  ([ .[] | select(.type == "custom-title") | .customTitle ] | last) as $ct
  | ([ .[] | select(.type == "ai-title") | .aiTitle ] | last) as $at
  | ([ .[] | select(.cwd != null) | .cwd ] | first) as $cwd
  | "\($u[-1].timestamp)\t\($ct // $at // "-")\t\($cwd // "-")\t\(input_filename | split("/") | last | rtrimstr(".jsonl"))\t\($u[0] | user_text | gsub("\\s+"; " ") | .[0:40])";
def is_claude:
  .type == "assistant" and (.isSidechain | not) and (claude_text | length > 0);
'

case "$cmd" in
  find)
    text="${1:-}"; [ -n "$text" ] || { echo "find には検索する文字列が要る" >&2; exit 2; }
    grep -lF -- "$text" "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null | while read -r f; do
      jq -r -s "$JQ_COMMON"'
        [ .[] | select(is_human) ] as $u
        | select($u | length > 0)
        | "\(input_filename | split("/") | .[-2])\t" + summary($u)
      ' "$f"
    done
    echo "（列: 記録のディレクトリ名 / 最後の発言 / タイトル / 作業ディレクトリ / セッション ID / 最初の発言。読むときは --dir ~/.claude/projects/<記録のディレクトリ名> show --session <ID>）" >&2
    ;;
  recent)
    n="${1:-20}"
    ls -t "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null | head -n "$n" | while read -r f; do
      jq -r -s "$JQ_COMMON"'
        [ .[] | select(is_human) ] as $u
        | select($u | length > 0)
        | summary($u)
      ' "$f"
    done | sort -r
    echo "（列: 最後の発言 / タイトル / 作業ディレクトリ / セッション ID / 最初の発言）" >&2
    ;;
  list)
    for f in $(files); do
      jq -r -s "$JQ_COMMON"'
        [ .[] | select(is_human) ] as $u
        | select($u | length > 0)
        | summary($u)
      ' "$f"
    done
    ;;
  show)
    since=""; user_only=0; session=""

    while [ $# -gt 0 ]; do
      case "$1" in
        --since) since="${2:-}"; shift 2 ;;
        --session) session="${2:-}"; shift 2 ;;
        --user-only) user_only=1; shift ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
      esac
    done
    targets="$(files)"
    if [ -n "$session" ]; then
      targets="$DIR/$session.jsonl"
      [ -f "$targets" ] || { echo "セッションが見つからない: $targets" >&2; exit 1; }
    fi
    for f in $targets; do
      jq -r --arg since "$since" --argjson uo "$user_only" "$JQ_COMMON"'
        select(.timestamp != null and .timestamp > $since)
        | if is_human then "\n[\(.timestamp)] USER (\(.sessionId)):\n\(user_text)"
          elif ($uo == 0 and is_claude) then "\n[\(.timestamp)] CLAUDE:\n\(claude_text)"
          else empty end
      ' "$f"
    done
    ;;
  *)
    sed -n '2,20p' "$0"; exit 2 ;;
esac
