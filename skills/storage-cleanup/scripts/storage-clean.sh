#!/usr/bin/env bash
# 再生成できるものだけを削除する。既定は dry-run（何を消すか表示するだけ）。
# Usage: storage-clean.sh [--apply] [--optimise] [--only nix|artifacts|caches|browsers]...
#   --apply     実際に削除する
#   --optimise  nix-store --optimise も実行する（時間がかかる）
#   --only      指定したカテゴリだけ処理する（複数指定可）
set -uo pipefail

APPLY=0
OPTIMISE=0
ONLY=()
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --optimise) OPTIMISE=1 ;;
    --only) shift; ONLY+=("${1:?--only needs a category}") ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

SC_PROJECT_ROOTS=("$HOME/projects")
SC_EXCLUDE=()
SC_STALE_DAYS=30
SC_NIX_KEEP=30d
CONFIG="${SC_CONFIG:-$HOME/.config/storage-cleanup/config}"
# shellcheck source=/dev/null
[ -f "$CONFIG" ] && . "$CONFIG"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

enabled() {
  [ ${#ONLY[@]} -eq 0 ] && return 0
  local c
  for c in "${ONLY[@]}"; do [ "$c" = "$1" ] && return 0; done
  return 1
}

free_gb() { echo $(( $(diskutil info -plist / | plutil -extract APFSContainerFree raw -) / 1000000000 )); }

# 実行する（dry-run なら表示のみ）。パイプで fallback を書かず、終了コードで判定する
run() {
  if [ "$APPLY" -eq 1 ]; then
    echo "+ $*"
    "$@" || echo "  ! failed ($?): $*" >&2
  else
    echo "would run: $*"
  fi
}

remove_dir() {
  local p="$1"
  [ -e "$p" ] || return 0
  if [ "$APPLY" -eq 1 ]; then
    echo "- rm -rf ${p/#$HOME/~} ($(human_kb "$(size_kb "$p")"))"
    rm -rf "$p"
  else
    echo "would remove: ${p/#$HOME/~} ($(human_kb "$(size_kb "$p")"))"
  fi
}

[ "$APPLY" -eq 1 ] && before=$(free_gb) && echo "free before: ${before} GB"
[ "$APPLY" -eq 0 ] && echo "(dry-run: --apply を付けると実際に削除します)"

if enabled nix && command -v nix-collect-garbage >/dev/null 2>&1; then
  echo "== nix"
  run nix-collect-garbage --delete-older-than "$SC_NIX_KEEP"
  [ "$OPTIMISE" -eq 1 ] && run nix-store --optimise
fi

if enabled artifacts; then
  echo "== build artifacts (stale > ${SC_STALE_DAYS}d, excluded: ${SC_EXCLUDE[*]+${SC_EXCLUDE[*]}})"
  list_build_artifacts | while IFS="$(printf '\t')" read -r status _ path; do
    [ "$status" = stale ] && remove_dir "$path"
  done
fi

if enabled caches; then
  echo "== tool caches"
  if command -v go >/dev/null 2>&1; then run go clean -cache; run go clean -modcache; fi
  if command -v npm >/dev/null 2>&1; then run npm cache clean --force; fi
  if command -v pnpm >/dev/null 2>&1; then run pnpm store prune; fi
  if command -v uv >/dev/null 2>&1; then run uv cache clean; fi
  if command -v brew >/dev/null 2>&1; then run brew cleanup --prune=all; fi
  for p in "${CACHE_DIRS[@]}"; do remove_dir "$p"; done
fi

if enabled browsers; then
  echo "== browser caches"
  for entry in "${BROWSER_CACHES[@]}"; do
    proc="${entry%%|*}"
    dir="${entry#*|}"
    [ -e "$dir" ] || continue
    if pgrep -xq "$proc"; then
      echo "skip: $proc is running (${dir/#$HOME/~})"
    else
      remove_dir "$dir"
    fi
  done
fi

if [ "$APPLY" -eq 1 ]; then
  after=$(free_gb)
  echo "free after: ${after} GB (+$((after - before)) GB)"
fi
