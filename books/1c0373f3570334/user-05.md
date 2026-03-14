---
title: "Home Manager の基本的な使い方"
---

# 1. この章でやること
この章では Home Manager の基本的な使い方を解説します。

まずは、パッケージを 1 つだけ Home Manager でインストールする流れを解説します。
その後、基本的な機能の使い方や更新方法を紹介します。


# 2. 最小構成で動かしてみる
## 2.1 home.nix にパッケージを追加
ここでは例として [nixfmt](https://github.com/NixOS/nixfmt) を追加します。

`home.nix` の `home.packages` を以下のように記述します。

```nix:home.nix
  home.packages = with pkgs; [
    nixfmt
  ];
```

:::details 記述方法の補足説明
Nix では、`pkgs.name` と書くとことで Nixpkgs からパッケージのビルド情報を参照できます。
**`pkgs` には参照する Nixpkgs のブランチ・リビジョンの情報、ビルド対象のプラットフォーム情報（OS・CPU アーキテクチャ）などが含まれています**。

>自動生成された `flake.nix` にて GitHub リポジトリやアーキテクチャ名が `pkgs` 変数に渡されています。

---

**`with pkgs;` について**。

`pkgs.` を何回も書く代わりに、`with` を利用すると楽に記述できます。

```nix
[
  pkgs.tool1
  pkgs.tool2
]
```

```nix
with pkgs; [
  tool1
  tool2
]
```

:::


## 2.2 反映する
以下を実行します。

```bash:Bash
home-manager switch --flake .
```


## 2.3 動作確認

```bash:Bash
nixfmt --version
```

バージョンが表示されれば成功です。


## 2.4 パッケージのアンインストール
動作確認が終わったので、nixfmt を入れていない状態に戻します。

`home.packages` のリストから削除します。

```nix:home.nix
  home.packages = with pkgs; [
  ];
```

環境を反映させます。

```bash:Bash
home-manager switch --flake .
```

以下を実行すると `command not found` となるはずです。

```bash:Bash
nixfmt --version
```

# 3. Home Manager の基本的な機能

:::message
**より実践的な使い方は次章で解説します**。
今の段階では `home.nix` を作り込まず、使い方に慣れることを目的としてください。
:::

## 3.1 パッケージのインストール home.packages
先ほども利用しましたが、`home.packages` にユーザー環境へ入れたいパッケージ名を記述します。

```nix:home.nix
  home.packages = with pkgs; [
    nixfmt
  ];
```

こちらのサイトで Nix で利用可能なパッケージを検索できます。

https://search.nixos.org/packages?channel=unstable

詳細はこちらをご確認ください。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/common-06


## 3.2 パッケージの設定ファイルの配置 home.file

:::message
**本セクションは実行せず、読むだけで大丈夫です**。
（既存の Git の設定ファイルと競合してしまうので。）

**次章では発展的な配置方法も紹介するので、それからどの方法を使うか選んでください**。

**次々章にて Git を Homebrew から移行する流れを解説します**。
**これら解説後、本格的に設定を作りこむのをおすすめします**。
:::

`home.file.<name>.source` では指定したファイルのシンボリックリンクを `~/` に作成します。

以下の例では、`~/work/dotfiles/home-manager/git/.gitconfig` が `~/.gitconfig` として配置されます。

```nix:/home.nix
  home.packages = with pkgs; [
    git
  ];

  # home.nix からの相対パスを指定
  home.file = {
    ".gitconfig".source = ./git/.gitconfig;
  };
```

```:フォルダ構成
dotfiles/
├─ flake.nix
└─ home-manager/
    ├─ home.nix
    └─ git/
        └─ .gitconfig
```


## 3.3 パッケージの設定ファイルの生成 programs.<package>

`programs.<package>` でインストールと設定ファイルを構築・配置できます。

以下の例では、Git の `user.name` と `user.email` が定義された設定ファイルが `~/.gitconfig` として配置されます。

```nix:home.nix
  home.packages = [
    # Git の記述は不要
  ];

  programs.git = {
    enable = true;  # ここで Git をインストールすると指定できる
    settings = {
      user = {
        name = "MyNixName";
        email = "MyEmail@example.com";
      };
    };
  };
```

:::message
`programs.git.settings` などは Home Manager 独自の関数です。
利用可能な関数は[Option Search というサイト](https://home-manager-options.extranix.com/)にて検索してください。
:::

参考までに、今回紹介しなかった別の方法（`home.file.<name>.text`）はこちらの記事で解説しています。

https://zenn.dev/trifolium/articles/642043cbae5f21


## 3.4 環境変数の設定 home.sessionVariables
`home.sessionVariables` にて設定できます。

```nix:~/.config/home-manager/home.nix
  home.sessionVariables = {
    GREETING = "Hello Nix";
  };
```

`home-manager switch` した後、シェルを読み込み直すと `GREETING` が設定されていることを確認できます。

```bash:Bash
$ echo $GREETING
Hello Nix
```


# 4. アップデート
## 4.1 パッケージの更新
`flake.nix` があるディレクトリ（`~/work/dotfiles`）にて、以下のコマンドを実行します。

```bash:Bash
nix flake update nixpkgs
```

`flake.lock` が更新され、パッケージのビルドレシピが最新になります。

その後、以下のコマンドを実行すると、パッケージが更新されます。

```bash:Bash
home-manager switch --flake .
```


## 4.2 Home Manager 本体の更新
`flake.nix` があるディレクトリ（`~/work/dotfiles`）にて、以下のコマンドを実行します。

```bash:Bash
nix flake update home-manager
```

先程と同様に、`flake.lock` が更新され、Home Manager のビルドレシピが最新になります。

以下のコマンドで更新されます。

```bash:Bash
home-manager switch --flake .
```


## 4.3 本体更新後の作業
**Home Manager 本体を更新した際は、リリースノートを確認してください**。

リリースノートに `home.stateVersion` を更新する旨が記載されていた場合、`home.nix` にて指定された値に更新してください。

- 公式リファレンス リリースノート

https://nix-community.github.io/home-manager/release-notes.xhtml

```nix:~/.config/home-manager/home.nix
  # 変更する場合、必ずリリースノートを確認する
  home.stateVersion = "25.11";
```

:::message
**`home.stateVersion` について**。

後方互換性を担保し、破壊的変更を防ぐための機能です。

必ずリリースノートを読み、既存の設定に悪影響を与えないか確認したうえで、リリースノートが指定した数値に変更してください。

**判断に迷う場合、現状の動作を維持したい場合は、無理に変更せず古い値のままで構いません。**

---

詳細は[公式リファレンス > Using Home Manager > Updating > State Version Management](https://nix-community.github.io/home-manager/index.xhtml#sec-upgrade-release-state-version) をご確認ください。
:::


# 5. Home Manager のアンインストール
以下のコマンドを実行します。

```bash:Bash
home-manager uninstall
```
