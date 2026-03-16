---
title: "Home Manager の設定ファイルの種類"
---

# 1. この章でやること
この章では Home Manager の設定ファイルについて解説します。


# 2. 設定ファイルの種類
Home Manager では `home.nix` と `flake.nix` の 2 つのファイルを利用します。

## 2.1 home.nix
自動生成された `home.nix` にはコメントによる解説が書かれている状態だと思います。
次章以降で解説する内容ですが、興味がある方は読んでみてください。

コメントを消すと以下のようになります。

```nix:home.nix
{ config, pkgs, ... }:

{
  home.username = "ryu";  # 環境依存、自動入力された値を使ってください
  home.homeDirectory = "/home/ryu";  # 環境依存、自動入力された値を使ってください
  home.stateVersion = "25.11";  # 環境依存、自動入力された値を使ってください

  home.packages = [
  ];

  home.file = {
  };

  home.sessionVariables = {
  };

  programs.home-manager.enable = true;
}
```

殆ど何も定義していない状態です。
**ここにユーザー環境へ入れたいパッケージなどを記述していきます**。



## 2.2 flake.nix
`flake.nix` は Home Manager 本体やインストールするパッケージの定義を管理します。

前章のインストール作業により、以下のようなファイルが生成されているかと思います。

>"ryu" と "x86_64-linux" の部分はインストールした PC の環境によって異なります。

```nix:flake.nix
{
  description = "Home Manager configuration of ryu";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ ./home.nix ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
    };
}
```

**重要な部分だけ解説していきます**。


### 2.2.1 inputs
以下の部分で利用する Home Manager のソースをどこから取得するかを定義しています。

```nix:flake.nix
  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager";
    };
  };
```

このコードの場合、home-manager のレポジトリにある `flake.nix` が情報源として定義されます。

https://github.com/nix-community/home-manager

:::message
例えば、`home-manager.lib` のように参照すると、`nix-community/home-manager/flake.nix` の `outputs` で定義されている `lib` を参照することになります。
:::


----

以下では、どの Nixpkgs を参照するかを定義しています。

```nix:flake.nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
```

ここでは、`nixos/nixpkgs` レポジトリの `nixos-unstable` ブランチが参照される設定になっています。
**これにより、どの情報源からパッケージの情報（Git のビルドレシピなど）を得るかを定義しています**。

Nixpkgs についてはこちらの章で解説しています。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/common-06


### 2.2.2 homeConfigurations
`flake.nix` の下側にある `homeConfigurations` にて、どの設定ファイルを追加で読み込むかを定義しています。

```nix:flake.nix
  homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
    modules = [ ./home.nix ];
  };
```

このコードでは、modules として `home.nix` を読み込むと定義されています。
**この `home.nix` の内容がユーザー環境設定の本体と言えます**。

:::message
リスト形式ですので、modules に複数の設定ファイル（`*.nix`）を渡すことも可能です。
パスは `flake.nix` からの相対パスを記述します。
:::


# 3. 設定ファイル関連のファイル
`dotfiles` レポジトリに `home.nix` と `flake.nix` の他に `flake.lock` があるかと思います。

これは `flake.nix` を利用した Nix の処理の過程で生成されるファイルです。
**`inputs` に定義した情報をベースにして、参照先を固定するのに利用されます**。

**このロックファイルにより、Home Manager 本体や導入するパッケージのバージョンが固定されます**。

:::details 具体例
`inputs` ではどのレポジトリを参照するかが記述しています。

```nix:flake.nix
  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager";
    };
  };
```

一方で、`flake.lock` ではどのリビジョン（コミットタイミング）を参照するのか、参照先の情報から計算したハッシュ値、などが記録されます。

**これにより、別の PC でも同じソースコードを参照できるようにしています**。

```nix:flake.lock
"home-manager": {
  "locked": {
    "lastModified": 1773422513,
    "narHash": "sha256-MPjR48roW7CUMU6lu0+qQGqj92Kuh3paIulMWFZy+NQ=",
    "owner": "nix-community",
    "repo": "home-manager",
    "rev": "ef12a9a2b0f77c8fa3dda1e7e494fca668909056",
    "type": "github"
  },
```

:::
