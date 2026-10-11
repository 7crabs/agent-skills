# storage-report.sh / storage-clean.sh 共通の定義。単体では実行しない。
# shellcheck shell=bash

ARTIFACT_NAMES=(node_modules target .venv venv .next build dist)

CACHE_DIRS=(
  "$HOME/.bun/install/cache"
  "$HOME/Library/Caches/pip"
  "$HOME/.gradle/caches"
  "$HOME/.gradle/wrapper"
  "$HOME/Library/Caches/ms-playwright"
  "$HOME/Library/Caches/node-gyp"
  "$HOME/.cargo/registry/cache"
  "$HOME/.cargo/registry/src"
)

# "プロセス名|キャッシュディレクトリ"。ブラウザ起動中は削除しない
BROWSER_CACHES=(
  "Google Chrome|$HOME/Library/Caches/Google/Chrome"
  "Brave Browser|$HOME/Library/Caches/BraveSoftware/Brave-Browser"
  "Microsoft Edge|$HOME/Library/Caches/Microsoft Edge"
  "firefox|$HOME/Library/Caches/Firefox"
)
BROWSER_CACHE_DIRS=()
for _entry in "${BROWSER_CACHES[@]}"; do BROWSER_CACHE_DIRS+=("${_entry#*|}"); done
unset _entry

# APFS のスパースファイル（Docker.raw 等）でも実使用量を返す
size_kb() { du -skx "$1" 2>/dev/null | awk '{print $1+0}'; }

human_kb() {
  awk -v k="${1:-0}" 'BEGIN{
    if (k >= 1048576) printf "%.1fG", k/1048576;
    else if (k >= 1024) printf "%.0fM", k/1024;
    else printf "%dK", k }'
}

watch_row() {
  local label="$1" path="$2"
  [ -e "$path" ] || return 0
  echo "| $label | $(human_kb "$(size_kb "$path")") | \`${path/#$HOME/~}\` |"
}

is_excluded() {
  local name="$1" pat
  for pat in "${SC_EXCLUDE[@]+"${SC_EXCLUDE[@]}"}"; do
    # shellcheck disable=SC2053
    [[ "$name" == $pat ]] && return 0
  done
  return 1
}

# プロジェクト内に、成果物ディレクトリと .git を除いて N 日以内に更新されたファイルがあるか
is_recent_project() {
  local proj="$1" prune=() n
  for n in "${ARTIFACT_NAMES[@]}" .git .direnv; do prune+=(-name "$n" -o); done
  unset 'prune[${#prune[@]}-1]'
  [ -n "$(find "$proj" \( -type d \( "${prune[@]}" \) -prune \) -o -type f -mtime -"$SC_STALE_DAYS" -print -quit 2>/dev/null)" ]
}

# 削除して安全な成果物か。誤検出しやすい名前は追加条件を課す
is_safe_artifact() {
  local dir="$1" parent name
  parent="$(dirname "$dir")"
  name="$(basename "$dir")"
  case "$name" in
    target) [ -f "$parent/Cargo.toml" ] || [ -f "$parent/pom.xml" ] || return 1 ;;
    build|dist)
      # git 管理下で、かつ追跡ファイルを含まない（= ignore された生成物）ときだけ
      git -C "$parent" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
      [ -z "$(git -C "$parent" ls-files -- "$name" 2>/dev/null | head -1)" ] || return 1
      ;;
  esac
  return 0
}

# 出力: status<TAB>size_kb<TAB>path  (status = stale | recent | excluded)
list_build_artifacts() {
  local root proj dir status name_expr=() n
  for n in "${ARTIFACT_NAMES[@]}"; do name_expr+=(-name "$n" -o); done
  unset 'name_expr[${#name_expr[@]}-1]'
  for root in "${SC_PROJECT_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    for proj in "$root"/*/; do
      proj="${proj%/}"
      [ -d "$proj" ] || continue
      if is_excluded "$(basename "$proj")"; then status=excluded
      elif is_recent_project "$proj"; then status=recent
      else status=stale
      fi
      find "$proj" -maxdepth 4 -type d \( "${name_expr[@]}" \) -prune -print 2>/dev/null |
        while read -r dir; do
          is_safe_artifact "$dir" || continue
          printf "%s\t%s\t%s\n" "$status" "$(size_kb "$dir")" "$dir"
        done
    done
  done | sort -t "$(printf '\t')" -k2,2nr | awk -F'\t' '$2 >= 10240'
}
