---
title: "公開リポジトリに置けないデータを Nix で管理下に置く"
emoji: "🦢"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [nix]
published: true
published_at: "2026-07-25 07:01"
---

# はじめに
public な dotfiles で Git の設定ファイルを管理した際、メールアドレス等の情報の扱いに困りました。

gitignore してローカル管理にすると、複数マシンを使う際、ファイルを手動更新するのが面倒です。
一方、SOPS 等で暗号化・復号して Git 管理下にするのは用途に対して過剰な気がします。

そこで、**Nix Flake の inputs にて private リポジトリ経由でデータを取得する構成にしました**。

本記事では、以下の 2 つの利用例を紹介します。

- dotfiles
  - `.nix` を外部から読み込み、処理で利用
- slide
  - 画像を外部から読み込み、ローカルに配置


# 前提

- Nix 導入済み


# 例 1：private の .nix ファイルを参照する
## 概要
home-manager にてユーザー環境へ配置する Git 設定ファイルを構築しています。
メールアドレスだけ非公開にしつつ、メールアドレスが定義されたファイルを参照できるように設定します。

実際のコードはこちらを参照ください。

https://github.com/ryuryu333/dotfiles


## 1.1 private リポジトリの準備
private リポジトリ（dotfiles-private）にて、メールアドレスを定義する `email.nix` ファイルを作成します。

```nix:dotfiles-private/git/email.nix
{
  programs.git.settings.user.email = "<my-mail>";
}
```

続いて、作成した `email.nix` を参照可能にするために `flake.nix` の outputs を定義します。

```nix:dotfiles-private/flake.nix
{
  description = "Private modules";

  outputs = { self }: {
    homeManagerModules.git-email = ./git/email.nix;
  };
}
```

## 1.2 private のデータを利用する側の設定
`flake.nix` の inputs に先ほど用意した private リポジトリを指定します。

```nix:flake.nix
  inputs = {
    dotfiles-private.url = "git+ssh://git@github.com/ryuryu333/dotfiles-private.git";
  };
```

outputs にて `dotfiles-private` から `homeManagerModules.git-email` を取り出します。

そして、home-manager や nix-darwin で利用するために、specialArgs に指定します。

```nix:flake.nix
outputs = { dotfiles-private, ... }:
  let
    git-email = dotfiles-private.homeManagerModules.git-email;
  in
  {
    # home-manager の場合
    homeConfigurations.example = home-manager.lib.homeManagerConfiguration {
      specialArgs = {
        inherit git-email;
      };
      modules = ...;
    };

    # nix-darwin で home-manager を管理している場合
    darwinConfigurations.example = nix-darwin.lib.darwinSystem {
      specialArgs = {
        inherit git-email;
      };
      modules = ...;
    };
  };
```

最後に、git-email と他の Git 定義とマージすれば終わりです。

```nix:git.nix
{ git-email, ... }:
{
  programs.git = {
    enable = true;
    settings = ...;
  };

  imports = [
    git-email
  ];
  # 実質、以下を追加した状態になる
  # programs.git.settings.user.email = "<my-mail>";
}
```

## 1.3 switch を実行
`home-manager switch` するとメールアドレスを含む Git 設定ファイルが生成・配置されます。

## 1.4 設定値を更新する場合
dotfiles-private を編集した後、dotfiles にて `nix flake update` します。


# 例 2：private の画像をローカルに配置する
## 概要
Marp CLI でスライドを作成する際、profile 画像を埋め込んでいます。
該当画像は規約上、再配布は NG です。
そのため、画像を gitignore しつつ、ローカルへの画像配置・更新を Nix の仕組みで行います。

実際のコードはこちらを参照ください。

https://github.com/ryuryu333/slide


## 2.1 private リポジトリの準備
1.1 と同じ手順です。
以下のように画像を配置し、outputs を定義します。

```:フォルダ構造
dotfiles-private
 └ slide/
    └  profile_icon.jpeg
```

```nix:dotfiles-private/flake.nix
{
  description = "Private modules";

  outputs = { self }: {
    slideAssets = ./slide;
  };
}
```

## 2.2 private のデータを利用する側の設定
`flake.nix` の inputs に dotfiles-private を追加します。

```nix:flake.nix
  inputs = {
    dotfiles-private.url = "git+ssh://git@github.com/ryuryu333/dotfiles-private.git";
  };
```

outputs にて `dotfiles-private` から `slideAssets` を利用します。

本例では、`slideAssets` から画像を指定し、ローカルにシンボリックリンクを作成する処理（app）を定義します。

```nix:flake.nix
outputs = { dotfiles-private, ... }:
  let
    pkgs = ...;

    place_slide_assets = pkgs.writeShellApplication {
      name = "place-slide-assets";
      text = ''
        mkdir -p slides/utl/images
        ln -sfn ${dotfiles-private.slideAssets}/profile_icon.jpeg slides/utl/images/profile_icon.jpeg
      '';
        };
  in
  {
    apps.place-slide-assets = {
      type = "app";
      program = "${place_slide_assets}/bin/place-slide-assets";
    };
  };
```

## 2.3 app を実行
以下のコマンドを実行すると、ローカルの `slides/utl/images/` に `profile_icon.jpeg` が配置されます。

```zsh:zsh
nix run .#place-slide-assets
```

## 2.4 画像を更新する場合
1.4 と同様に、dotfiles-private にて編集した後、slide で `nix flake update` します。


## 2.5 更に自動化させたい場合
devShell の shellHook にてシンボリックリンクを作る処理を書くだけです。

上記例では、配置・更新を明示的に行いたいので、app にしています。
どうせ一度行えば、devShell 起動の度に実施する意義は薄いので。


# おわりに
機密情報ではないが、public にはしたくないデータを Nix 経由で管理する方法を紹介しました。

**インターネット外部からはデータを隔離しつつ、手続き的な管理を減らし、宣言管理できます**。

漏洩時のリスクが小さい or ローカルは制約無しでネット公開だけ避けたい、といったデータなら、お手軽に隔離しつつ自身の運用負荷は小さいので、良いかと思いました。
