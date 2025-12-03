---
title: "home-manager で WSL と Mac の dotfiles を一括管理する"
emoji: "🐚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [nix, nixflakes, homemanager, dotfiles]
published: false
# published_at: "2025-12-05 07:00"
---

# はじめに
私は home-manager というツールでメイン PC（WSL）のユーザー環境を管理しています。

ここ最近、MacBook を購入した為、Mac も一緒に管理したいと考えました。
しかし、**OS が違うこともあり、個別の設定が多く存在し、1 つの `home.nix` を使いまわすのは困難でした**。

**単独の dotfiles 管理レポジトリで 2 つのユーザー環境を手軽に管理したいと思い試行錯誤した結果、良さげな方法を見つけたので記事にまとめます**。

大まかに紹介すると、`flake.nix` にて `homeConfigurations.user@hostname` を利用します。
**`home-manager switch` 実行時に環境を自動判定して、適切な設定ファイルが適用されるようにできます**。

```bash:WSL
$ home-manager switch
# `common.nix` と `wsl.nix` に基づいて環境が構築される
```

```bash:Mac
$ home-manager switch
# `common.nix` と `mac.nix` に基づいて環境が構築される
```

>※ `wsl.nix` などの中身は `home.nix` と同じ構造です。


# 想定読者

- home-manager で複数の環境を管理したい方
- home-manager を Flakes で管理している方
  - `flake.nix` を利用するため、nix-channel でインストールした方は対象外です

Flakes への移行はこちらの記事を参照ください。

https://zenn.dev/trifolium/articles/dafb565c778ed5

# 検証環境

- Windows 11
  - WSL2 Ubuntu 22.04.5 LTS
  - nix (Determinate Nix 3.8.2) 2.30.1
- MacBook Pro M1
  - nix (Determinate Nix 3.11.3) 2.31.2

どちらも Flakes 機能を有効化済み、かつ、Flakes を利用した Standalone installation で home-manager を導入済み。


# 設定方法

WSL、Mac 用のユーザー環境を定義するという仮定で、以下の作業していきます。

- 共通した設定を定義したファイルの作成（`common.nix`）
- 環境独自の設定を定義したファイルの作成（`wsl.nix`、`mac.nix`）
- 各環境の `USER` と `HOSTNAME` を確認
- `flake.nix` を編集
- `home-manager switch` で反映、完了！

```bash:フォルダ構成
home-manager/
├─ home/
│   ├─ common.nix
│   ├─ mac.nix
│   └─ wsl.nix
├─ flake.nix
├─ git/    # .gitconfig などを管理するフォルダ
├─ bash/
└─ zsh/
```


## 1. 共通した設定を定義したファイルの作成
`home.nix` に記述する設定の中で、各環境で共通する要素のみを抜き出したファイル `common.nix` を作成します。

```diff bash:フォルダ構成
 home-manager/
 └─ home/
+     └─ common.nix
```

<!-- cspell:disable -->

```nix:common.nix
{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    git
    direnv
    nix-direnv
    nixfmt
  ];

  home.file = {
    ".gitconfig".source = ../git/.gitconfig;
  };
}
```

<!-- cspell:enable -->


## 2. 環境独自の設定を定義したファイルの作成
WSL と MacBook 専用の設定ファイル `wsl.nix`、`mac.nix` を作成します。

```diff bash:フォルダ構成
 home-manager/
 └─ home/
      ├─ common.nix
+     ├─ mac.nix
+     └─ wsl.nix
```

```nix:wsl.nix
{ config, pkgs, ... }:

{
  home.username = "ryu";
  home.homeDirectory = "/home/ryu";

  home.packages = with pkgs; [
    bash
    # その他 WSL でのみ使うツールを指定
  ];

  home.file = {
    ".bashrc".source = ../bash/.bashrc;
    ".profile".source = ../bash/.profile;
  };
}
```

```nix:mac.nix
{ config, pkgs, ... }:

{
  home.username = "ryu";
  home.homeDirectory = "/Users/ryu";

  home.packages = with pkgs; [
    zsh
    # その他 Mac でのみ使うツールを指定
  ];

  home.file = {
    # ".zshrc".source = ../zsh/.zshrc;
    # ".profile".source = ../zsh/.profile;
  };
}
```


## 3. 各環境の `USER` と `HOSTNAME` を確認
以下のコマンドは筆者の例です。
次の作業で利用するのでメモしておきます。

```bash:bash WSL 環境
$ echo $USER
ryu

$ hostname
main
```

```zsh:zsh Mac 環境
$ echo $USER
ryu

$ hostname
MacBook.local
```

:::message
もしも、環境間で `USER@HOSTNAME` の文字列が同じであった場合、環境の区別ができるように変更してください。
:::


## 4. `flake.nix` を編集
`flake.nix` にて `homeConfigurations.USER@HOSTNAME` と記述することで、特定の環境用の設定を指定できます。
例えば、私の WSL 環境の場合は以下の様にします。

```nix
# USER = ryu、HOSTNAME = main
homeConfigurations."ryu@main" = home-manager.lib.homeManagerConfiguration {
  # 自身の環境のシステムを指定、M1 Mac なら aarch64-darwin
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  # 読み込む設定ファイルを指定
  modules = [
    ./home/common.nix
    ./home/wsl.nix
  ];
};
```

`flake.nix` のコード例は以下の通りです。

```diff bash:フォルダ構成
 home-manager/
 ├─ home/
 │   ├─ common.nix
 │   ├─ mac.nix
 │   └─ wsl.nix
+└─ flake.nix
```

```nix:flake.nix
{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }:
    {
      homeConfigurations = {
        # Main desktop PC, Windows 11, WSL (Ubuntu 22.04.5 LTS)
        "ryu@main" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            ./home/common.nix
            ./home/wsl.nix
          ];
        };
        # MacBook Pro M1
        "ryu@MacBook.local" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          modules = [
            ./home/common.nix
            ./home/mac.nix
          ];
        };
      };
    };
}
```

:::message
**`homeConfigurations` の仕様については記事後半で補足します**。
:::


## 5. 環境の反映
いつもと同じコマンドで環境を更新できます。

コマンド実行環境の `USER` と `HOSTNAME` に一致する `homeConfigurations` を自動的に選択して読み込んでくれます。

```bash:bash
home-manager switch
```


# （参考）homeConfigurations について
人力 & AI で検索したのですが、公式のリファレンスが見つけられませんでした。

2022 年の古いスレッドですが、ドキュメントには書かれていないロジックだとコメントされており、私と同じ状況でした。

https://discourse.nixos.org/t/get-hostname-in-home-manager-flake-for-host-dependent-user-configs/18859

ということで、ソースコードを見てきました。
どうやら `home-manager switch` コマンドの機能のようです。

**以下の内容は私の推測ベースなので話半分でお読みください**。

[こちらのファイル：home-manager/home-manager](https://github.com/nix-community/home-manager/blob/master/home-manager/home-manager) から抜粋した以下のコードが件のロジックかと思われます。

<!-- cspell:disable -->

```shell:home-manager
#!@bash@/bin/bash
# 省略...
function setFlakeAttribute() {
# 省略...
  local name="$USER"
  # Check FQDN, long, and short hostnames; long first to preserve
  # pre-existing behaviour in case both happen to be defined.
  for n in "$USER@$(hostname -f)" "$USER@$(hostname)" "$USER@$(hostname -s)"; do
      if [[ "$(nix eval "$flake#homeConfigurations" --apply "x: x ? \"$(escapeForNix "$n")\"")" == "true" ]]; then
          name="$n"
          if [[ -v VERBOSE ]]; then
              echo "Using flake homeConfiguration for $name"
          fi
      fi
  done
# 省略...
```

<!-- cspell:enable -->

`function doSwitch()` にて `function setFlakeAttribute()`、`function doBuildFlake()` の順で呼び出されているようです。

`function setFlakeAttribute()` の処理から、以下のルールのようです。

- `flake.nix` の `homeConfigurations` の名前が以下の 3 パターンと一致するかを判定
  - `$USER@$(hostname -f)`
  - `$USER@$(hostname)`
  - `$USER@$(hostname -s)`
- 一致したら名前を `name` に代入
- -> 以降の処理で `homeConfiguration.name` を利用

この仕組みによって、環境の `USER` と `HOSTNAME` を自動で読み取って、読み込む設定ファイルを切り替えてくれているようです。


# （参考）他の方法
上記の方法を見つける過程で他の方法も検討しました。
備忘録を兼ねて、簡単なメモを残しておきます。

方法 3 をより楽に実施できないかと調べた結果、今の方法に行きついた次第です。

#### 1. dotfiles レポジトリを OS 毎に作り、`home.nix` を用意する

- WSL と Mac で共通した設定を使いまわせない、管理コストが大きい


#### 2. 単独の dotfiles レポジトリで `home.nix` を用意し、if 文で頑張る

- 美しくない（主観）
  - 同じファイルに複数環境の記述を混在させるのは可読性が悪いと感じる
- 参考：「OS ごとの分岐を書きたいのだけれど？」項

https://apribase.net/2023/08/22/nix-home-manager-qa/

#### 3. 単独の dotfiles レポジトリで `wsl.nix`、`mac.nix` を用意する

- `home-manager switch` コマンドの引数指定が必要となり、手間がかかる
- 参考：「良い感じにしてみる」項

https://zenn.dev/ymat19/articles/beac3c1beccac4#%E8%89%AF%E3%81%84%E6%84%9F%E3%81%98%E3%81%AB%E3%81%97%E3%81%A6%E3%81%BF%E3%82%8B
