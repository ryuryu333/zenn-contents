---
title: "Nix 管理可能なパッケージの探し方 - Nixpkgs について"
---

# 1. この章でやること
この章では、Nixpkgs からパッケージを探す方法を解説します。

今後、ユーザー環境や開発環境のパッケージを管理する際の前提知識となります。


# 2. Nixpkgs とは
**[NixOS/nixpkgs という GitHub リポジトリ](https://github.com/NixOS/nixpkgs)には各種パッケージのビルド情報から Nix 言語で利用できるライブラリなど、様々な情報が集約されています**。

Nix でパッケージを導入する場合、大抵の場合は Nixpkgs にあるパッケージ情報を参照します。

:::details パッケージ情報の例
Rust 製の Python プロジェクトマネージャーである [uv](https://docs.astral.sh/uv/) を取り上げてみます。

[nixpkgs/pkgs/by-name/uv/uv/package.nix](https://github.com/NixOS/nixpkgs/blob/nixos-25.11/pkgs/by-name/uv/uv/package.nix) に uv のビルドレシピが定義されています。

このビルドレシピは Nix 言語で記述されており、uv の GitHub ページからソースコードを取得し、[Cargo](https://doc.rust-jp.rs/book-ja/ch01-03-hello-cargo.html) でビルドを行う流れが定義されています。

```:Nixpkgs にあるソースコード
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "uv";
  version = "0.9.29";

  src = fetchFromGitHub {
    owner = "astral-sh";
    repo = "uv";
    tag = finalAttrs.version;
    hash = "sha256-HsMZzn7D2C19Uu9xmz4NRaK+cGcoiyJYaAq1Z9f5nwY=";
  };

  # ...
```

>Cargo などビルドに使うツールのビルド方法、及び、`rustPlatform.buildRustPackage` といった関数も Nixpkgs で定義されています。

----

**Nixpkgs にある uv のビルドレシピを参照することで、uv を開発環境などで利用できるようになります**。

```:設定ファイルでの記述例
packages = with pkgs; [
  uv
];
```

:::


**2026/2/17 時点で、Nixpkgs には 138,910 種類のパッケージが登録されています**。
利用可能なパッケージの多さも Nix の魅力と言えるでしょう。

![パッケージ登録数](/images/1c0373f3570334/nixpkgs.png)

> [repology.org](https://repology.org/) より引用。Nixpkgs は右上端。


# 3. Nixpkgs のブランチ
Nixpkgs には多くのブランチが存在しますが、「更新タイミング」と「NixOS 向けかどうか」で大別できます。

代表的なブランチは以下の通りです。

| ブランチ | 更新タイミング | 利用対象 |
|:---:|:---:|:---:|
| master | 適宜（最新） | - |
| nixpkgs-unstable | CI/CD 完了後 | NixOS 以外 |
| nixos-unstable | CI/CD 完了後 | NixOS |
| nixpkgs-25.11 | 半年ごと | NixOS 以外 |
| nixos-25.11 | 半年ごと | NixOS |

:::message
**master は PR を出す際に利用することが多いと思います**。
**テストは最低限なので、普段使いには向きません**。

**nixpkgs/nixos-yy.mm はいわゆる stable ブランチです**。
**セキュリティアップデートのみが適時実施され、メジャーアップデートは半年ごとに反映されます**。
:::


**ツールの更新速度を優先する場合は、unstable を利用します**。
不安定と書かれていますが、テスト済みの更新内容だけが反映されるので、実質的には安定しています。

:::message
**特別な理由がなければ unstable を使うと思いますので、本書では nixpkgs-unstable 前提で解説します**。
:::

より詳細なブランチ情報が知りたい方はこちらを参照ください。

https://nixos.wiki/wiki/Nix_channels


# 4. Nixpkgs にパッケージがあるか調べる
こちらのサイトで Nixpkgs に登録されているパッケージを検索できます。

https://search.nixos.org/packages

例えば、`vim` で探すと以下のようになります。

![検索結果](/images/1c0373f3570334/c04/image.png)

**`nix-shell -p vim` と書かれているので、`vim` という名称で利用できると判断できます**。


:::message
**検索欄直下にある Channel について**。

先述した Nixpkgs のブランチを意味します。
新しいツールの場合、unstable でないとヒットしないかもしれません。
:::


:::message
**対応プラットフォームについて**。

Nix はプラットフォームに合わせたパッケージを自動的に導入してくれます。
しかし、**パッケージによっては未対応のプラットフォームがあります**。

Platforms 欄にも目を通しておくのを推奨します。

![対応アーキテクチャ](/images/1c0373f3570334/c04/image1.png)

一般的な Windows WSL（`x86_64-linux`）ならほとんどの場合対応しています。
Apple Silicon Mac（`aarch64-darwin`）は稀に対応していないパッケージがある印象です。
:::


# 5. Nixpkgs にない場合の方針
Nixpkgs に見当たらない場合は、**Homebrew など別のパッケージマネージャーで管理する**方針をおすすめします。

>ビルドレシピを自作すれば Nix 管理できますが、Nix 言語や関数を利用することになり、ハードルが高いかと思います。
