#!/usr/bin/env bash
# macOS のストレージ使用状況を読み取り専用で測り、Markdown レポートを保存する。
# Usage: storage-report.sh [--notify] [--stdout]
#   --notify  空きが SC_MIN_FREE_GB 未満なら macOS 通知を出す
#   --stdout  レポートをファイルに加えて標準出力にも出す
set -uo pipefail

NOTIFY=0
TO_STDOUT=0
for arg in "$@"; do
  case "$arg" in
    --notify) NOTIFY=1 ;;
    --stdout) TO_STDOUT=1 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

SC_PROJECT_ROOTS=("$HOME/projects")
SC_EXCLUDE=()
SC_STALE_DAYS=30
SC_MIN_FREE_GB=50
SC_REPORT_DIR="$HOME/.local/state/storage-cleanup/reports"
CONFIG="${SC_CONFIG:-$HOME/.config/storage-cleanup/config}"
# shellcheck source=/dev/null
[ -f "$CONFIG" ] && . "$CONFIG"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

mkdir -p "$SC_REPORT_DIR"
REPORT="$SC_REPORT_DIR/$(date +%Y-%m-%d_%H%M).md"

free_bytes=$(diskutil info -plist / | plutil -extract APFSContainerFree raw - 2>/dev/null || echo 0)
total_bytes=$(diskutil info -plist / | plutil -extract APFSContainerSize raw - 2>/dev/null || echo 0)
free_gb=$((free_bytes / 1000000000))

{
  echo "# Storage report $(date '+%Y-%m-%d %H:%M')"
  echo
  echo "- Container free: **${free_gb} GB** / $((total_bytes / 1000000000)) GB"
  echo "- Threshold (SC_MIN_FREE_GB): ${SC_MIN_FREE_GB} GB"
  echo

  echo "## APFS volumes"
  echo
  echo '```'
  diskutil apfs list 2>/dev/null | awk '/Name:/{sub(/^.*Name: +/,""); name=$0} /Capacity Consumed:/{sub(/^.*Consumed: +[0-9]+ B /,""); print name "\t" $0}'
  echo '```'
  echo

  echo "## Home top-level (du -x)"
  echo
  echo '```'
  du -xhd1 "$HOME" 2>/dev/null | sort -rh | head -20
  echo '```'
  unreadable=$(du -xs "$HOME" 2>&1 >/dev/null | grep -c "not permitted")
  echo
  echo "TCC 等で読めなかったディレクトリ数: ${unreadable}（実際より小さく出る。SKILL.md の「保護領域」参照）"
  echo

  echo "## Watchlist（利用状況次第で削除を検討するもの）"
  echo
  echo "| 対象 | 実使用量 | パス / 備考 |"
  echo "|---|---|---|"
  watch_row "Docker Desktop VM disk" "$HOME/Library/Containers/com.docker.docker/Data/vms"
  watch_row "Podman machine" "$HOME/.local/share/containers"
  watch_row "iOS Simulator devices" "$HOME/Library/Developer/CoreSimulator/Devices"
  watch_row "Xcode DerivedData" "$HOME/Library/Developer/Xcode/DerivedData"
  watch_row "Xcode iOS DeviceSupport" "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  watch_row "Android SDK" "$HOME/Library/Android/sdk"
  watch_row "Android AVD" "$HOME/.android/avd"
  watch_row "PatchKit apps (games)" "$HOME/Library/Application Support/PatchKit/Apps"
  watch_row "Steam" "$HOME/Library/Application Support/Steam"
  watch_row "Claude vm_bundles（削除対象外）" "$HOME/Library/Application Support/Claude/vm_bundles"
  watch_row "Ollama models" "$HOME/.ollama/models"
  watch_row "Hugging Face cache" "$HOME/.cache/huggingface"
  watch_row "omlx cache" "$HOME/.omlx/cache"
  watch_row "rustup toolchains" "$HOME/.rustup/toolchains"
  echo

  if command -v xcrun >/dev/null 2>&1; then
    echo "### Simulator runtimes"
    echo
    echo '```'
    xcrun simctl runtime list 2>/dev/null | grep -E "^(iOS|watchOS|tvOS|visionOS|xrOS)|Total Disk Images" || echo "(none)"
    echo '```'
    echo
  fi

  if command -v multipass >/dev/null 2>&1; then
    echo "### Multipass instances（実体は /var/root 配下。du では測れない）"
    echo
    echo '```'
    multipass info --all 2>/dev/null | grep -E "^Name|^State|^Disk usage" || echo "(multipassd not reachable)"
    echo '```'
    echo
  fi

  echo "## Nix"
  echo
  echo '```'
  diskutil apfs list 2>/dev/null | awk '/Name:/{sub(/^.*Name: +/,""); name=$0} /Capacity Consumed:/ && name ~ /Nix/{sub(/^.*Consumed: +[0-9]+ B /,""); print name "\t" $0}'
  for dir in "$HOME/.local/state/nix/profiles" /nix/var/nix/profiles /nix/var/nix/profiles/per-user/root; do
    [ -d "$dir" ] || continue
    ls "$dir" 2>/dev/null | sed -n 's/-[0-9]*-link$//p' | sort | uniq -c | awk -v d="$dir" '{print d "/" $2 ": " $1 " generations"}'
  done
  echo '```'
  echo

  echo "## Build artifacts（${SC_STALE_DAYS} 日以上未更新のプロジェクトが削除候補）"
  echo
  echo "| 状態 | サイズ | パス |"
  echo "|---|---|---|"
  list_build_artifacts | while IFS="$(printf '\t')" read -r status kb path; do
    echo "| $status | $(human_kb "$kb") | \`${path/#$HOME/~}\` |"
  done
  echo

  echo "## Caches"
  echo
  echo "| 対象 | サイズ |"
  echo "|---|---|"
  for p in "${CACHE_DIRS[@]}" "${BROWSER_CACHE_DIRS[@]}" "$HOME/.npm" "$HOME/Library/pnpm" "$HOME/go/pkg/mod" "$HOME/Library/Caches/go-build" "$HOME/.cache/uv" "$HOME/Library/Caches/Homebrew"; do
    [ -e "$p" ] || continue
    echo "| \`${p/#$HOME/~}\` | $(human_kb "$(size_kb "$p")") |"
  done
  echo

  echo "## Files over 1GB (home, -xdev)"
  echo
  echo '```'
  # -size は見かけのサイズなので、スパースファイルやクラウド上のプレースホルダを実使用量で除く
  find "$HOME" -xdev -type f -size +1G 2>/dev/null | while read -r f; do
    kb=$(size_kb "$f")
    [ "$kb" -ge 1048576 ] && printf "%s\t%s\n" "$(human_kb "$kb")" "${f/#$HOME/~}"
  done | sort -rh | head -20
  echo '```'
} > "$REPORT"

echo "report: $REPORT"
[ "$TO_STDOUT" -eq 1 ] && cat "$REPORT"

if [ "$NOTIFY" -eq 1 ] && [ "$free_gb" -lt "$SC_MIN_FREE_GB" ]; then
  osascript -e "display notification \"空き ${free_gb}GB（しきい値 ${SC_MIN_FREE_GB}GB）。レポート: $(basename "$REPORT")\" with title \"ストレージ残量が少なくなっています\""
fi
