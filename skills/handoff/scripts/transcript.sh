#!/usr/bin/env bash
# transcript.sh — Claude Code の会話記録（~/.claude/projects/<slug>/*.jsonl）から、
# カレントディレクトリで行った会話を読みやすい形で抜き出す。jq が必要。
#
# 使い方:
#   transcript.sh now                        現在時刻（UTC, ISO 8601）。HANDOFF.md の「最終更新」に使う
#   transcript.sh list                       セッション一覧（ID・最初と最後の時刻・最初の発言）
#   transcript.sh show [--since TS] [--user-only]
#       --since TS   この時刻（UTC, ISO 8601）より後の発言だけ
#       --user-only  ユーザーの発言だけ（既定はユーザーと Claude の本文。ツールの入出力は含めない）
#
# 記録の場所はカレントディレクトリから決まる。別の場所なら CLAUDE_TRANSCRIPT_DIR で指定する。

set -euo pipefail

DIR="${CLAUDE_TRANSCRIPT_DIR:-$HOME/.claude/projects/$(pwd | sed 's/[^A-Za-z0-9]/-/g')}"

cmd="${1:-}"; shift || true

if [ "$cmd" = "now" ]; then
  date -u +%Y-%m-%dT%H:%M:%SZ
  exit 0
fi

[ -d "$DIR" ] || { echo "会話記録が見つからない: $DIR（CLAUDE_TRANSCRIPT_DIR で指定できる）" >&2; exit 1; }
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
def is_claude:
  .type == "assistant" and (.isSidechain | not) and (claude_text | length > 0);
'

case "$cmd" in
  list)
    for f in $(files); do
      jq -r -s "$JQ_COMMON"'
        [ .[] | select(is_human) ] as $u
        | select($u | length > 0)
        | "\(input_filename | split("/") | last | rtrimstr(".jsonl"))\t\($u[0].timestamp)\t\($u[-1].timestamp)\t\($u[0] | user_text | gsub("\\s+"; " ") | .[0:60])"
      ' "$f"
    done
    ;;
  show)
    since=""; user_only=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --since) since="${2:-}"; shift 2 ;;
        --user-only) user_only=1; shift ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
      esac
    done
    for f in $(files); do
      jq -r --arg since "$since" --argjson uo "$user_only" "$JQ_COMMON"'
        select(.timestamp != null and .timestamp > $since)
        | if is_human then "\n[\(.timestamp)] USER (\(.sessionId)):\n\(user_text)"
          elif ($uo == 0 and is_claude) then "\n[\(.timestamp)] CLAUDE:\n\(claude_text)"
          else empty end
      ' "$f"
    done
    ;;
  *)
    sed -n '2,13p' "$0"; exit 2 ;;
esac
