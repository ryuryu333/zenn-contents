---
title: "nix-darwin のインストール"
---

# 1. この章でやること
この章では nix-darwin をインストールします。

:::message
手順は[公式ドキュメント > Getting started > Flakes](https://github.com/nix-darwin/nix-darwin) に準拠しています。
ただし、`flake.nix` の作成場所は変更しています。
:::


# 2. flake.nix の作成
任意の場所で `flake.nix` を作成します。

:::message
本書では、`~/work/dotfiles` に作成したと仮定して解説を進めていきます。
:::


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
`darwinConfigurations."<hostname>"` は自分の Mac のホスト名に置き換えてください。

```bash:Bash
hostname -s
```

`nixpkgs.hostPlatform = "<platform>"` は Intel Mac なら `x86_64-darwin`、Apple Silicon Mac なら `aarch64-darwin` に置き換えてください。

```bash:Bash
uname -m
```

:::


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
## 5.1 flake.nix の配置場所について
公式ドキュメントでは `/etc/nix-darwin` に `flake.nix` を作成・配置しています。

個人の好みですが、私は `/etc` のファイルを直接編集したり、Git 管理したくないです。
そのため、`~/work/dotfiles` で管理する方針にしています。
