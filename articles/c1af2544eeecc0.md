---
title: "Marp の外部 CSS を宣言的に管理する"
emoji: "🦉"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [nix, marp]
published: true
published_at: "2026-07-25 07:00"
---

# はじめに
Marp で外部 CSS（テーマ）を使う場合、通常はローカルに CSS をダウンロードする必要があります。

しかし、複数のマシンで Marp の編集環境を再現したい場合、それぞれのマシンで**手動ダウンロードするのは手間**です。

Private リポジトリであれば、CSS を Git 管理すれば解決できます。
一方、Public リポジトリの場合、ライセンス上は再配布可能であっても、第三者が作成した CSS を自分のリポジトリで直接管理することには抵抗があります。

また、**環境の再現性を確保するには、利用する CSS のバージョンも固定する必要があります**。

そこで、**Nix を用いて外部 CSS を含めた Marp 環境を宣言管理**しました。
本記事では、具体的な方法を紹介します。

----

実際に利用しているリポジトリはこちらです。
記事中のコード例はイメージですので、詳細はこちらをご確認ください。

https://github.com/ryuryu333/slide


# 想定読者

- Nix Flakes を利用している方
- Marp CLI で外部テーマを利用している方
- 外部テーマの CSS を自分のリポジトリへコピーしたくない方


# 概要
`flake.nix`の inputs に CSS 配布元（GitHub レポジトリ）を指定し、管理するだけです。

以降、こちらのテーマは利用する想定で設定していきます。

https://draculatheme.com/marp


# 設定方法
CSS の配布元のレポジトリを inputs に指定します。

https://github.com/dracula/marp

```nix:flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    marp-theme-dracula = {
      url = "github:dracula/marp";
      flake = false;
    };
  };
```

inputs から使いたい CSS があるフォルダを指定し、ローカルにシンボリックリンクを作成するスクリプトを定義します。

```nix:flake.nix
  outputs =
    {
      self,
      nixpkgs,
      marp-theme-dracula,
    }:
    let
      pkgs = ...;

      place_slide_assets = pkgs.writeShellApplication {
          name = "place-slide-assets";
          text = ''
          mkdir -p themes/third-party
          ln -sfn ${marp-theme-dracula}/dracula themes/third-party/dracula
          '';
      };
    in
    {
      apps.place-slide-assets = {
          type = "app";
          program = "${place_slide_assets}/bin/place-slide-assets";
      };
    }
```

以下のコマンドを実行すると、`themes/third-party/dracula` が生成されます。

```zsh:zsh
nix run .#place-slide-assets
```

`themes/third-party` は gitignore しておきます。

後は Marp CLI を使う devShell を定義して、利用するだけです。

:::message
`.marprc.yml`で CSS の配置場所を指定すると、`md` で簡潔に呼べるので楽です。

```yml:.marprc.yml
themeSet: ["./themes/**/*.css"]
```

```:main.md
---
marp: true
theme: dracula
---
```

:::


# 補足
## 運用について
今回は CSS の配置と開発環境（devShell）を別々にしました。
devShell の shellHook に CSS 配置処理を書くのも手だと思います。
毎回無駄な処理が走るのは嫌なので、明示的に配置・更新する運用にしました。


## CSS 指定のフォントについて
CSS 側で指定されたフォントを使う場合、devShell にて環境変巣 `FONTCONFIG_FILE` を定義する必要があります。

```nix:flake.nix
  devShell = ...
    FONTCONFIG_FILE = pkgs.makeFontsConf {
      fontDirectories = with pkgs; [
        noto-fonts-cjk-sans
      ];
    };
```
