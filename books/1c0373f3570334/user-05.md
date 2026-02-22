---
title: "Home Manager へ既存パッケージを移行する"
---

# 1. この章でやること
この章では、Homebrew で入れていた Git を home-manager に移行することを目標にします。


# 2. 最終形のイメージ
home-manager の設定は `~/.config/home-manager` に集約します。
この章のゴールは以下のような構成です。

```:フォルダ構成
~/.config/home-manager/
├── flake.lock
├── flake.nix
├── git
│   └── .gitconfig
└── home.nix
```

:::message
本章では `~/.config/home-manager` にファイルを置いていますが、私は `~/work/dotfiles/home-manager` にて管理しています。

`home-manager switch` は `~/.config/home-manager` を参照するので、シンボリックリンクを作成しています。

```bash:Bash
ln -s ~/work/dotfiles/home-manager ~/.config/home-manager
```

:::


# 3. Git を home-manager で管理する
## 3.1 home.nix に Git を追加
`home.nix` に Git を追加します。

```nix:~/.config/home-manager/home.nix
  home.packages = with pkgs; [
    git
  ];
```

反映します。

```bash:Bash
home-manager switch
```


:::message
前章でも解説しましたが、Homebrew と競合しないので、まだ Homebrew の Git をアンインストールしなくても大丈夫です。
移行が確認できてからアンインストールします。
:::


## 3.2 Git の設定ファイルを一緒に管理する
`~/.config/home-manager/git/.gitconfig` を用意し、既存の設定をコピペし、`home.nix` を以下のように記述します。

```nix:~/.config/home-manager/home.nix
  home.file = {
    ".gitconfig".source = ./git/.gitconfig;
  };
```

:::message
このままだと、すでに `~/.gitconfig` があった場合、home-manager が配置しようとする `.gitconfig` と競合します。

以下のコマンドを利用すると、既存の `~/.gitconfig` を `<filename>.backup` に置き換えてくれます。

```bash:Bash
home-manager switch -b backup
```

本章では、明示的に手動で動かすスタイルにします。
どちらでもいいです。
:::

`~/.gitconfig` を削除します。

>不安ならバックアップしてください。

```bash:Bash
rm ~/.gitconfig
```

home-manager の設定を反映します。

```bash:Bash
home-manager switch
```


# 4. Homebrew 版を削除する
削除前に、home-manager 管理の Git が利用できるかを確認します。

```bash:Bash
which git
```

以下のように `.nix-profile` と記述されていたら問題なしです。

```bash:Bash
/Users/ryu/.nix-profile/bin/git
```

Homebrew 管理の Git を削除します。

```bash:Bash
brew uninstall git
```


# 5. 以降は順次移行する
この章では **Git** を移行しました。
同じ手順で、Homebrew で入れていたツールを **ひとつずつ移行**していきます。

前章でも解説しましたが、移行の際は以下のサイトでツールが Nix で利用可能か検索してください。

https://search.nixos.org/packages


# 6. nixpkgs にないツールについて
Mac 専用のツールや一部の GUI ベースのアプリは nixpkgs に登録されていません。
そういったツールは Homebrew 管理のままにしてください。

:::message
今の状態ですと、PC 買い替え時に `home-manager switch` だけではユーザー環境が再現できず、Homebrew でのインストール作業も必要となります。

**次章から解説する nix-darwin を用いると、Homebrew も Nix で宣言的に管理でき、ワンコマンドで home-manager / Homebrew 管理下のツールを構築可能になります**。
:::
