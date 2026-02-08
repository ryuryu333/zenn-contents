---
title: "nix-darwin のインストール"
---

# 1. この章でやること
この章では **nix-darwin のインストール**を行います。

:::message
手順は[公式ドキュメント > Getting started > Flakes](https://github.com/nix-darwin/nix-darwin) に準拠しています。
ただし、`flake.nix` の作成場所は変更しています。
また、[Determinate Systems の Nix インストーラー](https://github.com/DeterminateSystems/nix-installer)を利用していることを前提としています。
:::


# 2. flake.nix の作成
任意の場所で `flake.nix` を作成します。

:::message
本書では、`~/work/dotfiles` に作成したと仮定して解説を進めていきます。
:::

`darwinConfigurations."<hostname>"` は自分の Mac のホスト名に置き換えてください。

```bash:Bash
hostname -s
```

`nixpkgs.hostPlatform = "<platform>"` は Intel Mac なら `x86_64-darwin`、Apple Silicon Mac なら `aarch64-darwin` に置き換えてください。

```bash:Bash
uname -m
```

```nix:~/work/dotfiles/flake.nix
{
  description = "nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, nix-darwin, ... }:
    {
      darwinConfigurations."<hostname>" = nix-darwin.lib.darwinSystem {
        modules = [
          {
            nixpkgs.hostPlatform = "<platform>";
            system.stateVersion = 6;
            nix.enable = false;
          }
        ];
      };
    };
}
```

:::message
この `flake.nix` では、最小構成の nix-darwin の設定を定義しています。
ユーザー環境・システム環境に変化は起こりません。

細かい設定方法は次章で解説します。
:::


# 3. インストールする
`flake.nix` があるディレクトリで、以下を実行します。

```bash:Bash
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .
```


# 4. インストール確認
以下で確認します。

```bash:Bash
darwin-version
```

バージョンが表示されればインストール完了です。


# 5. 補足
## 5.1 nix-darwin とは？
nix-darwin は、**Mac の設定を Nix で宣言的に管理するためのツール**です。
加えて、home-manager や Homebrew の設定もまとめて一元管理できます。


## 5.2 flake.nix の配置場所について
公式ドキュメントでは `/etc/nix-darwin` に `flake.nix` を作成・配置しています。

個人の好みですが、私は `/etc` のファイルを直接編集したり、Git 管理したくないです。
そのため、`~/work/dotfiles` で管理する方針にしています。


## 5.3 Nix インストーラーによる違い
本章では Determinate Systems の Nix インストーラーを利用していることを前提に、最小構成の設定を `flake.nix` に記述しています。

通常は nix-darwin が Nix の設定管理を行いますが、今回は Determinate に任せるために `nix.enable = false;` としています。

>設定しない場合、Nix 管理が競合してエラーとなります（`error: Determinate detected, aborting activation`）。

---

公式インストーラーを利用した場合は以下のように設定します。

```nix
{
    nixpkgs.hostPlatform = "<platform>";
    system.stateVersion = 6;
    # Flakes 機能を有効化
    nix.settings.experimental-features = "nix-command flakes";
}
```
