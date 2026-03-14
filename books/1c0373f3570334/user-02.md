---
title: "Home Manager のインストール"
---

# 1. この章でやること
この章では Home Manager のインストールを行います。

:::message
手順は[公式リファレンス > Nix Flakes > Standalone setup](https://nix-community.github.io/home-manager/index.xhtml#ch-nix-flakes) をベースにしています。
:::


# 2. dotfiles ディレクトリの準備
ユーザー環境を管理するためのディレクトリとして、`~/work/dotfiles` を用意します（場所は任意）。
**今後の工程ではこのディレクトリに全ての設定ファイルを集約していきます**。

:::details dotfiles とは
明確な定義はありませんが、一般的には、ホームディレクトリにある設定ファイル（`~/.gitconfig` 等）を意味します。

転じて、ユーザー環境を管理することを指す言葉でもあります。
:::

:::message
既存の dotfiles がある場合でも、Home Manager の設定を同居されることは可能だと思います。
今後の解説では、`dotfiles/flake.nix`、`dotfiles/flake.lock`、`dotfiles/home-manager/*` を作成していきます。
他のフォルダ・ファイルがあっても（基本的には）問題は起こらないはずです。
:::


# 3. 設定ファイルの作成
dotfiles ディレクトリに移動してから、以下のコマンドを実行します。

```bash:Bash
cd ~/work/dotfiles
```

```bash:Bash
nix run home-manager/master -- init .
```


:::details コマンド解説
`nix run ...` とすると、パッケージをインストールせずに実行できます（`npx` コマンドみたいなイメージ）。

```bash:Bash
# home-manager をインストールせずに実行
nix run home-manager/master -- <command>

# インストール済みの環境における下記コマンドと同義
home-manager <command>
```

`home-manager init` で設定ファイルを自動生成できます。

```bash:Bash
home-manager init <path>
```

>path 未指定時はデフォルト値（`~/.config/home-manager`）に生成されます。

:::


:::message
Home Manager のダウンロード処理が行われるので、完了まで十数秒かかるかと思います。
:::


Home Manager の `init` コマンドにより `dotfiles/flake.nix`、`dotfiles/home.nix` が生成されます。
Git 管理に加えてください。

```bash:Bash
git init
git add flake.nix home.nix
git commit -m "generate Home Manager config file"
```

:::details add しなかった場合
Nix の仕様により、`flake.nix` が Git 追跡状態で無い場合、今後の工程で以下のようなエラーが発生します。

```bash:Bash
$ nix run home-manager/master -- switch --flake .
# ...
error: Path 'flake.nix' in the repository "/home/ryu/work/dotfiles" is not tracked by Git.
# ...
```

**Nix ではコマンド操作する前に新規ファイルは `git add` する、と覚えておくとよいでしょう**。

>補足すると、より正確には Nix の Flakes という機能の仕様です。
Flakes では Git 追跡されたファイルのみを利用します（通常の操作の場合）。
そのため、`flake.nix` 本体や `flake.nix` 内で参照するファイルが Git 追跡されていないと、ファイルが見つからない！とエラーが発生します。

:::


# 4. インストール
以下のコマンドで Home Manager をインストールします。

```bash:Bash
nix run home-manager/master -- switch --flake .
```


:::details コマンド解説
`nix run` を使い、ユーザー環境にない home-manager コマンドを利用しています。

書き下すと、以下のようなコマンドになります。

```bash:Bash
home-manager switch --flake .
```

`switch` コマンドで Home Manager の設定ファイルを読み込み、ユーザー環境に反映できます。

`--flake` オプションを付けると、参照する設定ファイルを指定できます。
未指定時は `~/.config/home-manager/flake.nix` が参照されます。

:::


# 5. インストール確認
以下で確認します。

```bash:Bash
home-manager --version
```

バージョンが表示されればインストール完了です。

```bash:Bash
$ home-manager --version
26.05-pre
```

:::message
この段階では、Home Manager がインストールされただけで、ユーザー環境に変化は起こりません。
Homebrew 管理下のパッケージは問題なく利用できます。
:::


# 6. 補足
## 6.1 参考資料

- Home Manager GitHub ページ

https://github.com/nix-community/home-manager

- 公式リファレンス

https://nix-community.github.io/home-manager/index.xhtml


## 6.2 インストール方法の種類
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


## 6.3 バージョン管理方法の種類
Home Manager 本体、および、導入するパッケージのバージョン管理方法は **nix-channel / Flake** の 2 パターンあります。

nix-channel が標準的な方法とされていますが、バージョン情報を Git 管理に反映させるのが手間です。

一方、Flakes を使うと **ロックファイルでバージョンを固定**できます。
これにより、Git にてバージョン管理やロールバックが容易になります。

**本章では Flakes 管理を前提に解説しています**。
