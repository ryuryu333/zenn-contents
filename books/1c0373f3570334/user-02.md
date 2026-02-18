---
title: "Home Manager のインストール"
---

# 1. この章でやること
この章では **Home Manager のインストール**を行います。

:::message
手順は[公式リファレンス > Nix Flakes > Standalone setup](https://nix-community.github.io/home-manager/index.xhtml#ch-nix-flakes) に準拠しています。
:::


# 2. インストール
任意の場所で以下のコマンドを実行します。

```bash:Bash
nix run home-manager/master -- init --switch
```

Home Manager のダウンロード処理が行われるので、完了まで十数秒かかるかと思います。

:::message
インストール処理の過程で `~/.config/home-manager/` に設定ファイル（`flake.nix`、`home.nix`）が生成されます。
次章ではこの `home.nix` を編集して、Home Manager を利用します。
:::


# 3. インストール確認
以下で確認します。

```bash:Bash
home-manager --version
```

バージョンが表示されればインストール完了です。

:::message
この段階では、Home Manager がインストールされただけで、ユーザー環境に変化は起こりません。
Homebrew 管理下のパッケージは問題なく利用できます。
:::


# 4. シェルの設定
Home Manager を利用する前に 1 つだけ前準備が必要です[^1]。

[^1]: 公式リファレンス > Installing Home Manager > Standalone installation > 4.: https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone

利用しているシェルにて Home Manager が作成した環境変数を利用可能にするため、以下を `~/.profile`（Bash）や `~/.zprofile`（Zsh）等に追記してください。

```bash
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
```

これで作業は完了です。


# 5. 補足
## 5.1 参考資料

- Home Manager GitHub ページ

https://github.com/nix-community/home-manager

- 公式リファレンス

https://nix-community.github.io/home-manager/index.xhtml


## 5.2 インストール方法の種類
Home Manager の導入方法は大きく分けて **Standalone** と **モジュール**の 2 パターンあります。

| 方法 | 概要 |
|:----:|:----:|
|Standalone|単体で Home Manager を使う|
|NixOS module|NixOS に組み込む|
|nix-darwin module|nix-darwin に組み込む|

**本章では最も基本的な利用方法である Standalone でインストールしています**。

:::message
残り 2 つは、NixOS や macOS 限定の方法となります。

本書の第三部では、nix-darwin というツールで Mac のシステム設定からユーザー環境までを包括的に管理する方法を解説します。
この際、nix-darwin module として Home Manager を利用します。
:::


## 5.3 バージョン管理方法の種類
Home Manager 本体、および、導入するパッケージのバージョン管理方法は **nix-channel / Flake** の 2 パターンあります。

nix-channel が標準的な方法とされていますが、バージョン情報を Git 管理に反映させるのが手間です。

一方、Flakes を使うと **ロックファイルでバージョンを固定**できます。
これにより、Git にてバージョン管理やロールバックが容易になります。

**本章では Flakes 管理を前提に解説しています**。
