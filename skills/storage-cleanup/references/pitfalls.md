# ストレージ調査の落とし穴

実際の調査でつまずいた点。

## 測り方

- **`du` には `-x` を付ける。** 付けないと、`/Library/Developer/CoreSimulator/...` にマウントされたシミュレータのディスクイメージまで数え、数十 GB を重複計上する。
- **`/System/Volumes/Data` を起点に測る。** `/` から測ると firmlink 経由で同じ領域を二重に数える。
- **スパースファイルは見かけと実使用量が違う。** `Docker.raw` や Podman の `.raw` は `ls -l` で 60〜100GB でも実体は数 GB のことがある。判断は `du`（割り当て済みブロック）で行う。`find -size` も見かけのサイズで判定する。
- **クラウドストレージのプレースホルダ**（Google Drive, iCloud）は見かけが大きくても実体がない。
- **APFS のクローンは `du` で二重に数えられる**（過大側に振れる）。
- `diskutil info -plist /` の `APFSContainerFree` が空き容量の一次情報。`df` は volume ごとの数字で、コンテナの共有空きと混同しやすい。

## 権限

- TCC 保護領域（`~/.Trash`, Photos, Mail, Messages, ブラウザのプロファイルなど）は、フルディスクアクセスのないプロセスからは `Operation not permitted` になる。`du` はエラーを出してそのディレクトリを 0 として合計するので、合計が過小になる。エラー件数を数えて報告する。
- Claude デスクトップの Code タブのシェルは `Claude.app` → `disclaimer` → 別署名の `claude.app` の配下で動く。アプリ本体にフルディスクアクセスを付けても効かない。
- `sudo` でも読めない場所（SIP 保護の `/private/var/db/*` など）がある。数十 GB の説明のつかない差が残ることがあるが、OS 管理領域なので深追いしない。
- Multipass の VM は `/var/root/Library/Application Support/multipassd` にあり root でないと測れない。`multipass info --all` で各インスタンスの使用量は取れる。

## 削除

- **`cmd | tail -1 || fallback` では fallback が動かない。** パイプラインの終了コードは最後のコマンド（`tail`）のもの。`command -v` で分岐するか、`if cmd; then ...; else ...; fi` で書く。
- `nix-collect-garbage` をオプションなしで実行しても古い世代が GC ルートとして残るので何も消えない。`--delete-older-than` か `-d` が要る。直後に `nix-store --optimise` するとハードリンク化でさらに減る（時間がかかる）。
- root プロファイルの世代は `sudo nix-collect-garbage ...` が別途必要。
- `xcrun simctl runtime delete` 後も `/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime/` に `NeverCollected` の asset が残ることがある。SIP 保護下で、Apple はサポートされた削除手段を示していない。再起動後にランタイムが再登録される報告もあるので、再起動後に `xcrun simctl runtime list` を確認する。
- `build` / `dist` はソースとして git 管理されていることがある。git 管理下で、追跡ファイルを含まないときだけ生成物とみなす。`target` は `Cargo.toml` か `pom.xml` が隣にあるときだけ。
- ブラウザのキャッシュは起動中に消さない。
