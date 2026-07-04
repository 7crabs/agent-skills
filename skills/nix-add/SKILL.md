---
name: nix-add
description: home-manager管理のdotfilesにNixパッケージを追加する。「〜をインストールして」「〜を使えるようにして」とツール導入を求められたときに使う。
---

# Add Nix Package
1. Find the home.nix or relevant module file in ~/dotfiles/
2. Add the requested package to home.packages or the appropriate module
3. Run `home-manager switch --flake ~/dotfiles/` to apply
4. Verify the package is available with `which <package-name>`
