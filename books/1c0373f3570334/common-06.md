---
title: "Nix 管理可能なパッケージの探し方と運用の基本"
---

# 1. この章でやること
この章では、Nix で管理できるパッケージの探し方、更新方法を解説します。

今後、ユーザー環境や開発環境のパッケージを管理する際の前提知識となります。


# 2. Nixpkgs について
[NixOS/nixpkgs という GitHub リポジトリ](https://github.com/NixOS/nixpkgs)には各種パッケージのビルド情報から Nix 言語で利用できるライブラリなど、様々な情報が集約されています。

Nix でパッケージを導入する場合、大抵の場合は Nixpkgs にあるパッケージ情報を参照します。

:::message
例として、Rust 製の Python プロジェクトマネージャーである [uv](https://docs.astral.sh/uv/) を取り上げてみます。

[nixpkgs/pkgs/by-name/uv/uv/package.nix](https://github.com/NixOS/nixpkgs/blob/nixos-25.11/pkgs/by-name/uv/uv/package.nix) に uv のビルドレシピが定義されています。

このビルドレシピは Nix 言語で記述されており、uv の GitHub ページからソースコードを取得し、[Cargo](https://doc.rust-jp.rs/book-ja/ch01-03-hello-cargo.html) というツールでビルドを行う流れが定義されています。

>Cargo などビルドに使うツールのビルド方法も別途 Nixpkgs で定義されています。

----

Nixpkgs にある uv のビルドレシピを参照する（`package = pkgs.uv` のように記述する）ことで、uv を開発環境などで利用できるようになります。
:::


2026/2/17 時点で、Nixpkgs には 138,910 種類のパッケージが登録されています。
この利用可能なパッケージの多さも Nix の魅力と言えるでしょう。

![パッケージ登録数](/images/1c0373f3570334/nixpkgs.png)

> [repology.org](https://repology.org/) より引用。


# 3. Nixpkgs のブランチ
Nixpkgs には多くのブランチが存在しますが、「更新タイミング」と「NixOS 向けかどうか」で大別できます。

代表的なブランチを紹介します。

| ブランチ | 更新タイミング | 利用対象 |
|:---:|:---:|:---:|
| master | 適宜（最新） | - |
| nixpkgs-unstable | テスト完了後 | 非 NixOS |
| nixos-unstable | テスト完了後 | NixOS |
| nixpkgs-25.11 | 半年ごと | 非 NixOS |
| nixos-25.11 | 半年ごと | NixOS |

>master は PR を出す際に利用することが多いと思います。テストは最低限なので、普段使いには向きません。
nixpkgs/nixos-yy.mm はいわゆる stable ブランチです。
セキュリティアップデートのみが適時実施され、メジャーアップデートは半年ごとに反映されます。


**ツールの更新速度を優先する場合は、unstable を利用します**。
不安定と書かれていますが、テスト済みの更新内容だけが反映されるので、実質的には安定しています。

:::message
**特別な理由がなければ unstable を使うと思いますので、本書では nixpkgs-unstable 利用前提で解説します**。
:::

より詳細なブランチ情報が知りたい方はこちらを参照ください。

https://nixos.wiki/wiki/Nix_channels


# 4. Nixpkgs にパッケージがあるか調べる
こちらのサイトで Nixpkgs に登録されているパッケージを検索できます。

https://search.nixos.org/packages

例えば、`vim` で探すと以下のようになります。

![検索結果](/images/1c0373f3570334/c04/image.png)

`nix-shell -p vim` と書かれているので、`vim` という名称で登録されていると判断できます。


:::message
**検索欄直下にある Channel について**。

先述した Nixpkgs のブランチを意味します。
新しいツールの場合、unstable でないとヒットしないかもしれません。
:::


:::message
**対応プラットフォームについて**。

Nix はプラットフォームに合わせたツールを自動的に導入してくれます。
しかし、**ツールによっては未対応のプラットフォームがあります**。

Platforms 欄にも目を通しておくのを推奨します。

![対応アーキテクチャ](/images/1c0373f3570334/c04/image1.png)

一般的な Windows WSL（`x86_64-linux`）ならほとんどの場合対応しています。
Apple Silicon Mac（`aarch64-darwin`）は時々対応していないツールがある印象です。
:::


# 5. Nixpkgs にない場合の方針
Nixpkgs に見当たらない場合は、**Homebrew など別のパッケージマネージャーで管理する**方針をおすすめします。

>ビルドレシピを自作すれば Nix 管理できますが、Nix 言語や関数を利用することになり、ハードルが高いかと思います。


# 6. パッケージの更新
**ロックファイルを更新する**ことで Nix で構築するパッケージのバージョンを更新できます。

```bash:Bash
nix flake update
```

詳細は次章以降で扱いますが、大まかなイメージは以下の通りです。

1. 設定ファイル（`flake.nix`）にてどのツールを導入するか等の設定を記述する。
2. ロックフィル（`flake.lock`）で参照する Nixpkgs のリビジョンを固定する。
（参照するビルドレシピが固定され、パッケージのバージョンが固定される）
3. `flake.nix` に基づいて、パッケージがビルドされる。
4. `flake.nix` に基づいて、ユーザー環境 or 開発環境が構築される。

:::message
ロックファイルの仕様上、**パッケージは一斉に更新されます**。
個別に更新する方法は別途解説します。
:::

:::message
素の状態の Nix ではロックファイル（`flake.lock`）は生成しません。
これは実験的機能 Flakes を用いた際の挙動になります。

**Flakes はその利便性から実質的なスタンダードとなっていますので、本書では Flakes 利用を前提として解説します**。
:::

