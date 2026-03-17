---
title: "1.2 Nix 導入の利点・活用例"
---

# 1. この章でやること
この章では、Nix を導入すると何ができるようになるのかを、ユーザー環境と開発環境の 2 軸で紹介します。

:::message
**理解しやすいように簡易化したコード例を記載しています**。

ここでは、**本書の内容を全て実施した場合の雰囲気**（＝**設定を宣言的に記述するスタイル**）を知っていただければ幸いです。
:::


# 2. ユーザー環境の管理
## 2.1 モチベーション
私は Windows11（WSL2 Ubuntu 22.04.5 LTS）、MacBook Pro M1 をプライベートで利用しています。

私は面倒くさがりなので、PC 買い替え時、いかに手軽にユーザー環境を再現できるかを重視しています。
また、バージョン違いに起因するエラーを考慮したくないので、**依存を含む全てのパッケージのバージョンを再現したい**と考えています。
加えて、**異なる OS 間でも可能な限り同じバージョンに揃えたい**です。

**そこで、採用したのが Nix です**。

現在は、1 つの GitHub リポジトリに dotfiles（`.gitconfig` 等）を集約し、複数のマシンのユーザー環境を管理しています。


## 2.2 環境移行
以前、MacBook を購入した際は一日で移行作業が終わり、その楽さに感動しました。

以下の 3 ステップでユーザー環境が再現できます。

- Nix をインストール
- `git clone <mydotfiles>`
- ビルドコマンドを実行する


## 2.3 パッケージの追加
パッケージの追加作業はシンプルです。

一般的なパッケージマネージャーではコマンドを実行することから始まるかと思います。

```zsh:Homebrew の場合
brew install git
```

一方、Nix では設定ファイルにパッケージ名を宣言し、ビルドコマンドを実行します。

```nix:Nix の場合
home.packages = with pkgs; [
    # Git をインストール
    git
];

home.file = {
    # dotfiles にある .gitconfig を ~/.gitconfig として配置
    ".gitconfig".source = ./git/.gitconfig;
};
```

```zsh:環境の反映コマンド
home-manager switch
```

**設定ファイルを Git 管理しておけば、別の PC でも同じバージョン・同じ設定の Git を利用できるので楽です**。


# 3. 開発環境の構築
## 3.1 モチベーション
環境差異に起因したエラーを考慮したくないので、私はプロジェクトの実行環境の再現性を重視しています。

過去では、プロジェクトごとに Docker コンテナで環境を構築していました。
しかし、ここまで極端にすると日常のちょっとした開発には運用が重いです。

かといって、プロジェクト A 用のパッケージがプロジェクト B から見える（影響を及ぼし得る）ことは許容できません。

**そこで、Nix を採用しました**。

Nix で開発に必要なパッケージを依存から含めてバージョン固定し、専用の環境を構築できます。
また、Nix で構築した環境内からホスト環境にアクセスできる（ユーザー環境の Git 等が使える）ため、Docker よりも手軽な運用にできます。

>※より厳密な再現性を求める場合は、Docker と Nix を組み合わせることもできます。


## 3.2 開発環境の例
私が普段利用している環境例を紹介します。

プロジェクトディレクトリに設定ファイルを作成し、使用するツールを記述すると、各パッケージがその環境内でのみ利用可能になります。

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

Python を扱う場合、Python ライブラリ管理は uv に移譲しつつ、それ以外のパッケージを Nix で構築しています。

>Nix で Python ライブラリを管理すると複雑な運用になるので、uv を併用しています。

```nix:work/python_project/flake.nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    python312
    uv
    go-task
  ];
};
```

direnv というツールと併用すると、各ディレクトリを開くと自動的に Nix による環境が起動されるので、楽です。

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

パッケージを追加・削除する際は設定ファイルからパッケージ名を追記・削除するだけです。
direnv により、ターミナルを触ると自動的に環境が再構築されます。

`uv add pandas` のようなコマンド操作ではなく、設定ファイルを編集・更新するというフローは違和感があるかもしれません。
しかし「その環境に何が必要なのか？」を宣言するだけですので、慣れると楽です。


:::message
**プロジェクト毎で別々の Python や Node.js を使うことも容易です**。

また、パッケージ A とパッケージ B が同じライブラリ X を必要とし、異なるバージョンを要求したとしても、異なるバージョンのライブラリ X がそれぞれビルドされるので安心です。
（各ツール専用のライブラリ X が用意されるイメージ。）
:::


# 4. （おまけ）Mac のシステム設定の管理
かなり特殊な例かもしれませんが、Mac のシステム設定を管理する用途でも Nix は使えます。

Dock や FInder の設定、キーコンフィグ、ダークモード有効化、様々な設定を**宣言的に管理**できます。

<!-- cspell:disable -->

```nix:設定例
    # Finder
    finder = {
      AppleShowAllExtensions = true; # ファイル拡張子を常に表示
      AppleShowAllFiles = true; # 隠しファイルを表示
      FXDefaultSearchScope = "SCcf"; # 検索範囲をカレントフォルダに設定
      ShowPathbar = true; # パスバーを表示
      FXEnableExtensionChangeWarning = false; # ファイル拡張子変更の警告を無効化
      FXPreferredViewStyle = "Nlsv"; # デフォルトの表示方法をリストビューに設定
    };
    # 画面キャプチャ
    screencapture = {
      target = "clipboard"; # スクリーンショットの保存先をクリップボードに設定
      disable-shadow = true; # スクリーンショットの影を無効化
    };
```

<!-- cspell:enable -->

Mac の買い替えの面倒さがかなり低減できるので気に入っています。


