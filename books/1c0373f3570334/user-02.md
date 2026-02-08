---
title: "home-manager のインストール"
---

# 1. この章でやること
この章では **home-manager のインストール**を行います。

:::message
手順は[公式リファレンス > Nix Flakes > Standalone setup](https://nix-community.github.io/home-manager/index.xhtml#ch-nix-flakes) に準拠しています。
:::


# 2. インストール
任意の場所で以下のコマンドを実行します。

```bash:Bash
nix run home-manager/master -- init --switch
```

home-manager のダウンロード処理が行われるので、完了まで十数秒かかるかと思います。

:::message
インストール処理の過程で `~/.config/home-manager/` に設定ファイル（`flake.nix`、`home.nix`）が生成されます。
次章ではこの `home.nix` を編集して、home-manager を利用します。
:::


# 3. インストール確認
以下で確認します。

```bash:Bash
home-manager --version
```

バージョンが表示されればインストール完了です。

:::message
この段階では、home-manager がインストールされただけで、ユーザー環境には変化は起こりません。
Homebrew 管理下のツールは問題なく利用できる状態です。
:::


# 4. シェルの設定
home-manager を利用する前に 1 つだけ前準備が必要です[^1]。

[^1]: 公式リファレンス > Installing Home Manager > Standalone installation > 4.: https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone

利用しているシェルにて home-manager が作成した環境変数を利用可能にするために、以下を `.profile`（Bash）や `.zprofile`（Zsh）等に追記してください。

```bash
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
```

これで作業は完了です。


# 5. 補足
## 5.1 home-manager とは？
home-manager は、**ユーザー環境を宣言的に管理するためのツール**です。
ツールの導入、dotfiles（`.gitconfig`）の配置等を管理できます。

home-manager は `home.nix`、`flake.nix` に設定を記述します。
詳細は次章で解説します。

- home-manager GitHub ページ

https://github.com/nix-community/home-manager

- 公式リファレンス

https://nix-community.github.io/home-manager/index.xhtml


## 5.2 インストール方法の種類
home-manager の導入方法は大きく分けて **Standalone** と **モジュール**の 2 系統あります。

- Standalone: 単体で home-manager を使う（この章の方法）
- NixOS module: NixOS の設定に組み込む
- nix-darwin module: Mac の nix-darwin 設定に組み込む（本書の後半で扱います）
- flake-parts module: flake-parts で用いる場合

**本章では最も基本的な利用方法である Standalone でインストールしています**。


## 5.3 バージョン管理方法の種類
home-manager 本体、および、導入するツールのバージョン管理方法は **nix-channel / Flake** の 2 パターンあります。

- nix-channel: 標準的な方法
- Flakes: Nix の実験的機能 Flakes を用いた方法（この章の方法）

Flakes を使うと **ロックファイルでソフトの依存関係が固定**できます。
ロックファイルを Git 管理することで、バージョンの固定・再現が容易になります。


:::message
nix-channel の場合、CLI での操作によってバージョンを更新します。
そのままだと Git 管理が困難であるため、ロックファイルとして管理できる Flakes を選択しました。

このように、Flakes は便利な機能が多く、実験的（experimental）機能という立ち位置ながら、実質的なスタンダードとなっています。
:::
