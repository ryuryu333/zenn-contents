---
title: "第二部 ユーザー環境の管理"
---

第二部では、Home Manager でユーザー環境を管理する方法を解説します。

Nix では [Profiles という機能](https://nix.dev/manual/nix/2.25/package-management/profiles)を用いて、ユーザー環境にパッケージをインストールできます。
この Profiles をベースにして、**ユーザー環境の管理に特化したツール**が Home Manager です。

https://github.com/nix-community/home-manager

----

**Home Manager を利用することで、複雑な Nix 式を記述せずに設定を記述できます**。

例えば、入れたいパッケージはリスト形式で記述するだけです。

```nix:設定例
home.packages = with pkgs; [
  git
  vim
];
```

また、パッケージごとの設定ファイルを生成したり、既存の設定ファイルのシンボリックリンクを作成する機能もあり、便利です。

```nix:設定例
programs.git = {
  settings = {
    user = {
      name = "MyNixName";
      email = "MyEmail@example.com";
    };
  };
};

home.file = {
  ".gitconfig".source = ./git/.gitconfig;
};
```

----

次章からは Home Manager でユーザー環境を管理する方法を解説していきます。

:::message
**Home Manager は既存のパッケージマネージャーと共存できます**。

本書では、Homebrew でユーザー環境のパッケージを管理している状態から、Home Manager を導入する前提で解説します。
:::


# 目次

1. [Home Manager のインストール](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/user-02)
2. [Home Manager の設定ファイルの種類](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/user-03)
3. [Home Manager インストール後の初期設定](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/user-04)
4. [Home Manager の基本的な使い方](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/user-05)
5. [Home Manager の実践テクニック](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/user-06)
6. [Home Manager へ既存パッケージを移行する](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/user-07)
7. [Home Manager と Homebrew の共存](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/user-08)

