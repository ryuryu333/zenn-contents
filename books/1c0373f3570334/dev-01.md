---
title: "第四部 開発環境の管理"
---

第四部では、Nix で開発環境を管理する方法を解説します。

Flakes devShell という機能を用いると、プロジェクト単位で必要なパッケージが揃ったシェル環境を構築できます。

グローバルにインストールせず、プロジェクト内でのみパッケージが利用可能となります。
**グローバル環境を汚さずに済むのが利点です**。

また、設定ファイル（`flake.nix`）に宣言的に記述するため、Git 管理と相性が良いです。
**`git clone` してから `nix develop` するだけで必要なパッケージが揃い、かつ、依存を含めたバージョンが統一できるのも利点です**。
個人利用でもマシン間の環境差分を減らせますし、チーム運用ならばより利点が際立つかと思います（パッケージごとのインストール手順書を作成せずに済むので楽です）。


::::::details Docker との違い
独立した環境を構築する、という点は Docker と似ていますが、**アプローチが全く異なります**。

:::message
Docker は隔離された独立のアプリケーション実行環境を構築します。
一方、devShell は名前の通り、シェル環境を作るだけです。
:::

----

devShell を起動すると、`flake.nix` に定義したパッケージがビルド・ダウンロードされます。
そして、それらが PATH に追加されたシェル環境が構築されます。

つまり、**devShell を用いると、ユーザー環境に PATH などが追加された状態のシェル環境が立ち上がります**。

Docker と異なり、環境は隔離されていません。
そのため、**プロジェクトの外へアクセス可能です（ユーザー環境にあるパッケージを利用できます）**。


:::message
Docker よりも手軽に扱えながら、環境（パッケージのインストールとバージョン）を揃えられることが devShell の利点です。
:::

----

ただし、**OS 差分の吸収という観点では Docker に軍配が上がります**。

devShell では異なる OS でも同じバージョンのパッケージが揃います。
しかし、**パッケージによっては未対応の OS もあるので、個別対応が必要となることもあります**。

また、**OS 機能に依存した処理が含まれる場合、Nix ではカバーできません**。

このように Nix 単独では再現性が担保できない領域は存在します。

:::message
上記のような問題に直面した場合、Docker と Nix を併用するアプローチもあります。
（OS 環境の再現性を Docker で担保して、パッケージの再現性を Nix で担保するイメージ）

また、[Docker イメージを Nix で構築するといった方法](https://nix.dev/tutorials/nixos/building-and-running-docker-images.html)もあります。

発展的な内容になるので、本書では扱いません。
:::

::::::


# 目次

1. [Flakes devShell の基本な使い方](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/dev-02)
2. [devShell を自動起動する - nix-direnv](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/dev-03)
3. [flake.nix と devShell の書き方](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/dev-04)
4. [devShell 以外の方法での開発環境管理](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/dev-05)
5. [テンプレートの活用](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/dev-06)
6. [Flakes テンプレートを自作 & 公開する](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/dev-07)
7. [flake.nix をリモートへ反映させずに使う](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/dev-08)
