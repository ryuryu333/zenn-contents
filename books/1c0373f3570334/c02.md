---
title: "Nix 導入の利点・活用例"
---

# 1. この章でやること
この章では、Nix を導入すると何ができるようになるのかを、ユーザー環境と開発環境の 2 軸で紹介します。

:::message
理解しやすいように簡易化したコード例も記載します。
詳細は次章以降で解説します。
ここでは、本書の内容を全て実施した後の雰囲気（＝**Nix で設定を宣言的に記述する・環境を再現する**）を知っていただければ幸いです。
:::


# 2. ユーザー環境の構築
## 2.1 モチベーション
Windows11（WSL）と MacBook（M1）をプライベートでは利用しています。

私は面倒くさがりなので、PC 買い替え時、いかに手軽にユーザー環境を再現できるかを重視しています。
また、ツールのバージョン違いに起因するエラーを考慮したくないので、依存を含む全てのツールのバージョンを再現したいと考えています。
加えて、異なる OS 間でも可能な限り同じバージョンに揃えたいです。

**そこで、採用したのが Nix です**。

現在は、一つの GitHub リポジトリに dotfiles（`.gitconfig` 等）を集約し、ツールの導入・設定を管理しています。
Nix のロックファイルを Git 管理し、依存を含むツール一式のバージョンを統一・再現できるようにしています。


## 2.2 環境を移行する場合
以下の 3 ステップでユーザー環境が再現できます。

- Nix をインストール
- git clone <mydotfiles>
- ビルドコマンドを実行する

以前、MacBook を購入した際は一日で移行作業が終わり、その楽さに感動しました。


## 2.3 ツールの追加
ツールの追加作業もシンプルです。

```bash:Bash
brew install git
```

する代わりに、設定ファイルにツール名を追記し、ビルドコマンドを実行するだけです。

```nix:dotfiles/home-manager/home.nix
home.packages = with pkgs; [
    ...
    git  # Git をインストール
];

home.file = {
    # dotfiles にある .gitconfig を ~/.gitconfig として配置
    ".gitconfig".source = ./git/.gitconfig;
};
```

設定ファイルを `git push` しておけば、別の PC でも同じバージョン・同じ設定の Git を利用できます。


# 3. 開発環境の構築
## 3.1 モチベーション
環境差異に起因したエラーを考慮したくないので、私はプロジェクトの実行環境の再現性を重視しています。

過去では、プロジェクトごとに Docker コンテナで環境を構築していました。
しかし、ここまで極端にすると日常のちょっとした開発には運用が重いです。

かといって、プロジェクト A 用のツールがプロジェクト B から見える（影響を及ぼし得る）ことは許容できません。

**そこで、Nix を採用しました**。

Nix で開発に必要なツールを依存から含めてバージョン固定し、各ツールが揃った専用の環境を構築できます。
また、Nix で構築した環境内からホスト環境にアクセスできる（ユーザー環境の Git 等が使える）ため、Docker よりも手軽な運用にできます。

>※より厳密な再現性を求める場合は、Docker と Nix を組み合わせることもできます。


## 3.2 開発環境の例
私が普段利用している環境例を紹介します。

プロジェクトディレクトリに設定ファイルを作成し、使用するツールを記述すると、各ツールがその環境内でのみ利用可能になります。

```nix:work/data_analysis/flake.nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    terraform
    google-cloud-sdk
    dbt
    go-task
  ];
};
```

Python を扱う場合、Python ライブラリ管理は uv に移譲しつつ、それ以外のツールを Nix で構築しています。

>Nix で Python ライブラリを管理すると複雑な運用になるので、uv を併用しています。

```nix:work/python_project/flake.nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    python312
    uv
    ollama
    go-task
  ];
};
```

direnv というツールと併用すると、各ディレクトリを開くと自動的に Nix による環境を起動できます。

```bash:Bash
$ cd work/python_project

$ uv --version
uv x.x.xx

$ cd ..

$ uv --version
command not found: uv
```

```bash:Bash
$ cd work/python_project

# Nix で構築した環境内からユーザー環境のツールを利用可能
$ git --version
git version x.xx.x
```

:::message
プロジェクト毎で別々の Python や Node.js を使うことも容易です。

また、ツール A とツール B が同じライブラリ X を必要とし、かつ、異なるバージョンを要求したとしても、異なるバージョンのライブラリ X がそれぞれビルドされるので、安心です。
（各ツール専用のライブラリ X が用意されるイメージ。）
:::
