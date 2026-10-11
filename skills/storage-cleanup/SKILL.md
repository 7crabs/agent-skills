---
name: storage-cleanup
description: macOS のストレージを分析し、再生成できるものから順に掃除する。「容量がパツパツ」「ディスクを掃除したい」「何が容量を食っているか調べて」と言われたとき、または storage-report の通知を受けてユーザーが相談してきたときに使う。
allowed-tools: Bash(bash ~/.claude/skills/storage-cleanup/scripts/storage-report.sh:*), Bash(bash ~/.claude/skills/storage-cleanup/scripts/storage-clean.sh), Read, AskUserQuestion
---

# ストレージの分析と掃除

測る → 説明のつかない差を潰す → 安全なものを消す → 判断が要るものをユーザーに聞く、の順に進める。**削除はすべてユーザーの承認を得てから**行う。

## 道具

| スクリプト | 役割 |
|---|---|
| `scripts/storage-report.sh [--stdout] [--notify]` | 読み取りのみ。Markdown レポートを `SC_REPORT_DIR`（既定 `~/.local/state/storage-cleanup/reports/`）に保存 |
| `scripts/storage-clean.sh [--apply] [--optimise] [--only <cat>]` | 再生成できるものだけを削除。既定は dry-run。カテゴリは `nix` `artifacts` `caches` `browsers` |

設定は `~/.config/storage-cleanup/config`（ひな形: `config.example`）。対象ディレクトリ、除外するプロジェクト、未更新とみなす日数などを置く。リポジトリには個人の設定を書かない。

## 手順

### 1. 測る

1. `bash ~/.claude/skills/storage-cleanup/scripts/storage-report.sh --stdout` を実行する
2. `SC_REPORT_DIR` に前回のレポートがあれば読み、増えた場所を挙げる
3. 「Data ボリュームの使用量」と「測れた合計」の差を出す。差が大きいときは 2 へ

### 2. 説明のつかない差を潰す

差の主な行き先は次の 3 つ。順に確認する。

| 行き先 | 確認方法 |
|---|---|
| TCC 保護領域（Photos, Mail, Messages, ブラウザのプロファイル, ゴミ箱など） | ユーザーの Terminal で測ってもらう（下記） |
| root 所有の領域（`/private/var/root` に置かれる VM、Spotlight インデックスなど） | 同上。`sudo` が要る |
| SIP 保護領域・APFS メタデータ | 測れない。手動で消す対象でもないので深追いしない |

**Claude Code のシェルからは保護領域を読めないことがある。** デスクトップアプリの Code タブは、アプリ本体とは別の署名のバイナリ配下でシェルを動かす。アプリ本体にフルディスクアクセスを付けても効かない。ユーザーに次を Terminal.app で実行してもらい、出力ファイルを Read する。

```bash
du -sh ~/.Trash ~/Pictures/*.photoslibrary ~/Library/{Mail,Messages,Safari,"Daemon Containers"} ~/Library/"Application Support"/{Google/Chrome,BraveSoftware/Brave-Browser,discord} 2>&1 | tee ~/protected_du.txt
sudo sh -c 'du -xhd2 /System/Volumes/Data/Library /System/Volumes/Data/private/var/root /System/Volumes/Data/.Spotlight-V100 2>/dev/null | sort -rh | head -30' | tee ~/root_du.txt
```

システム設定 > 一般 > ストレージ のスクリーンショットも有用。画面の合計は Data + System ボリュームで、別ボリューム（Nix Store など）は含まない。

### 3. 安全なものを消す

1. `bash ~/.claude/skills/storage-cleanup/scripts/storage-clean.sh` で dry-run し、対象を表にしてユーザーに見せる
2. ブラウザのキャッシュはブラウザ起動中は自動でスキップされる。消したいならブラウザを閉じてもらう
3. 承認を得たら、ユーザーに `--apply` 付きで実行してもらうか、承認を得て実行する。`--apply` は `allowed-tools` に含めていない
4. Go のモジュールキャッシュなどを消すと次回ビルドで再ダウンロードになる。直近に大事なビルドがあるなら伝える

### 4. 判断が要るものを聞く

レポートの Watchlist と大きいファイルから候補を挙げ、AskUserQuestion で使っているかを聞く。消し方は正規の手段を使う。

| 対象 | 消し方 |
|---|---|
| Docker Desktop | アプリの Troubleshoot > Clean / Purge data（`Docker.raw` を直接消さない） |
| iOS シミュレータ | `xcrun simctl delete unavailable` / `delete all`、`xcrun simctl runtime delete <id>` |
| Android | SDK Manager か `~/Library/Android/sdk`・`~/.android/avd` の削除 |
| Multipass | `multipass delete <name> && multipass purge` |
| Podman | `podman machine rm`（本体が無ければ `~/.local/share/containers`） |
| ランチャー経由のゲーム | ランチャーからアンインストール（不可ならデータフォルダ） |
| 古い Rust ツールチェーン | `rustup toolchain uninstall <ver>`。`rust-toolchain*` での固定がないか先に確認 |
| Nix の古い世代 | `nix-collect-garbage --delete-older-than 30d`（オプションなしでは世代が残るので何も消えない） |

ソフト本体を残すかどうかはデータと分けて確認する。

### 5. 消さないもの

- Claude デスクトップの `vm_bundles`（再取得される）
- `/System/Library/AssetsV2` の MobileAsset。特に `NeverCollected` のシミュレータランタイム。Apple はサポートされた削除手段を示していない
- Spotlight インデックス、SIP 保護領域

### 6. 記録する

作業ディレクトリにレポートがあれば、実施内容・前後の空き容量・保留にしたものを追記する。

## 注意

- 判断材料は [references/pitfalls.md](references/pitfalls.md) を参照（`du` の数え方、スパースファイル、シェルの書き方の落とし穴）
- 事実（コマンド出力）と推測を分けて報告する。推測には根拠を添える
