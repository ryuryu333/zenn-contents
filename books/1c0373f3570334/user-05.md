---
title: "Home Manager の基本的な使い方"
---

# 1. この章でやること
この章では Home Manager の基本的な使い方を解説します。

まずは、パッケージを 1 つだけ Home Manager でインストールする流れを解説します。
その後、基本的な機能の使い方や更新方法を紹介します。


# 2. 最小構成で動かしてみる
## 2.1 設定ファイルを開く
Home Manager をインストールする際に自動生成された `~/.config/home-manager/` フォルダを開きます。

`home.nix` にユーザー環境の設定を記述します。


:::message
`flake.nix` と `flake.lock` は自動的に生成された状態のままで大丈夫です。
これらはパッケージのバージョン管理に用いるファイルです。
:::


自動生成された `home.nix` にはコメントによる解説が書かれている状態だと思います。
これから解説しますが、興味がある方は読んでみてください。

コメントを消すと以下のようになります。


```nix:~/.config/home-manager/home.nix
{ config, pkgs, ... }:

{
  home.username = "ryu"; # ユーザー環境に依存
  home.homeDirectory = "/Users/ryu"; # ユーザー環境に依存

  home.stateVersion = "25.11"; # Home Manager のバージョンに依存

  home.packages = [
  ];

  home.file = {
  };

  home.sessionVariables = {
  };

  programs.home-manager.enable = true;
}
```

:::message
**`home.username`、`home.homeDirectory`、`home.stateVersion` は必ず自動生成された値を利用してください**。
:::


## 2.2 home.nix にパッケージを追加
ここでは例として **nixfmt** を追加します。

>`.nix` ファイル用のフォーマッターです。

`home.packages` に `nixfmt` を記述します。


```nix:~/.config/home-manager/home.nix
  home.packages = with pkgs; [
    nixfmt
  ];
```

:::details 記述方法の補足説明
Nix では、`pkgs.toolname` と書くとことで Nixpkgs からパッケージのビルド情報を参照できます。
`pkgs` には参照する Nixpkgs のブランチ・リビジョンの情報、ビルド対象のプラットフォーム情報（OS・CPU アーキテクチャ）などが含まれています。

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


## 2.3 反映する
以下を実行します。

```bash:Bash
home-manager switch
```

:::message
このコマンドにより、`~/.config/home-manager/flake.nix` と `home.nix` の情報が読み込まれます。

`home.nix` に記述されているパッケージがビルドされ、PATH されることで、ユーザー環境（グローバル）で呼び出せるようになります。
:::


# 3. 使えるようになったか確認

```bash:Bash
nixfmt --version
```

バージョンが表示されれば成功です。


# 4. パッケージのアンインストール
動作確認が終わったので、nixfmt を入れていない状態に戻します。

`home.packages` のリストから削除します。

```nix:~/.config/home-manager/home.nix
  home.packages = [
  ];
```

環境を反映させます。

```bash:Bash
home-manager switch
```

以下を実行すると `command not found` となるはずです。

```bash:Bash
nixfmt --version
```


# 5. Homebrew と競合しないの？
**同じパッケージが入っていても問題ありません**。  
実際に使われるのは **PATH の先にある方**です。

確認したい場合は `which` / `which -a` でどちらが使われているか分かります。

本書をお読みの方は nixfmt を Homebrew 等でインストールしていないと思いますので、以下の様に表示されるはずです。

```bash:Bash
$ which nixfmt
/Users/ryu/.nix-profile/bin/nixfmt

$ which -a nixfmt
/Users/ryu/.nix-profile/bin/nixfmt
```

>Users/ryu の部分は自身の環境のユーザー名になります。


## 5.1 Homebrew と Home Manager で同じパッケージを入れてみる

:::message
**このセクションは気になる方のみお読みください**。

コードは実行せず、読むだけで大丈夫です。
Nix によるビルド仕様の解説が含まれるので、難しいと思ったら読み飛ばしてください。
:::

::::::details 長いので折りたたみ
敢えて、nixfmt を Homebrew でインストールしてみます。

```bash:Bash
$ brew install nixfmt

$ brew list | grep nixfmt
nixfmt
```

この状態で `which` / `which -a` を確認します。

```bash:Bash
$ which nixfmt
/Users/ryu/.nix-profile/bin/nixfmt

$ which -a nixfmt
/opt/homebrew/bin/nixfmt
/Users/ryu/.nix-profile/bin/nixfmt
```

このように、**Home Manager と Homebrew で管理された nixfmt が共存しています**。

`home-manager switch` を行うと、Nix 管理下の nixfmt が環境変数 `PATH` の先頭寄りに登録されるため、Homebrew ではなく **Home Manager の nixfmt が優先して呼ばれる**状態になります。

そのため、**Home Manager の設定から nixfmt を除外すれば、Homebrew の nixfmt が実行できます**。


## 5.2 依存ライブラリの扱い
nixfmt に紐づけられている shared libraries を otool で確認します。

**Homebrew 側では `/usr/lib/~`、Home Manager 側では `nix/store/~` となっていることに注目してください**。

<!-- cspell:disable -->

```bash:Bash
$ otool -L /opt/homebrew/bin/nixfmt
/opt/homebrew/bin/nixfmt:
        /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1351.0.0)
        /usr/lib/libiconv.2.dylib (compatibility version 7.0.0, current version 7.0.0)
        /opt/homebrew/opt/gmp/lib/libgmp.10.dylib (compatibility version 16.0.0, current version 16.0.0)
        /usr/lib/libffi.dylib (compatibility version 1.0.0, current version 40.0.0)
        /usr/lib/libcharset.1.dylib (compatibility version 1.0.0, current version 1.0.0)
```

```bash:Bash
$ otool -L /Users/ryu/.nix-profile/bin/nixfmt
/Users/ryu/.nix-profile/bin/nixfmt:
        /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.100.2)
        /nix/store/6nmmi317rg2bnybndbgc944dpg5cnl5a-libiconv-109.100.2/lib/libiconv.2.dylib (compatibility version 7.0.0, current version 7.0.0)
        /nix/store/c3pfhyhy0hyhff79slz8js78gv2zrg27-gmp-with-cxx-6.3.0/lib/libgmp.10.dylib (compatibility version 16.0.0, current version 16.0.0)
        /nix/store/n8ylivq3rz4dai1yfrf71xqc2fyvwrcn-libffi-40/lib/libffi.7.dylib (compatibility version 9.0.0, current version 9.0.0)
```

<!-- cspell:enable -->

:::message
`/usr/lib/libSystem.B.dylib` は Nix 管理外じゃないか！と思うかもしれませんが、これは仕様です。
libSystem は macOS に強く紐づいているので例外的な処置となっています。

参考資料: [リンク](https://daiderd.com/2020/06/25/nix-and-libsystem.html)

このような例外を除き、**Nix は依存を含めてビルドします**。
そして、これら**依存ライブラリのバージョンはロックファイルで固定**されます。
:::

:::message
仮に、別のソフトで nixfmt と同じライブラリを必要となり、かつ、違うバージョンが要求された場合、バージョン毎に `nix/store/hash-name-version` が作成されます。

同じライブラリをバージョン毎に用意するので、**ソフト A をインストールしたらソフト B の依存ライブラリが変更された、という状況を防げます**。

これは Nix の大きな魅力だと思います。
:::

::::::


# 6. Home Manager の基本的な機能

:::message
より実践的な使い方は次章で解説します。
今の段階では `home.nix` を作り込まず、使い方を学ぶことを主としてください。
:::

## 6.1 パッケージのインストール home.packages
先ほども利用しましたが、`home.packages` にユーザー環境へ入れたいパッケージ名を記述します。

```nix:~/.config/home-manager/home.nix
  home.packages = with pkgs; [
    nixfmt
  ];
```

こちらのサイトで Nix で利用可能なパッケージを検索できます。

https://search.nixos.org/packages?channel=unstable

詳細は第一部の「Nix 管理可能なパッケージの探し方と運用の基本」をご確認ください。


## 6.2 パッケージの設定ファイルの配置 home.file

:::message
**本セクションは実行せず、読むだけで大丈夫です**。
（既存の Git の設定ファイルと競合してしまうので。）

具体的な Git の移行作業は次章以降で解説します。
:::

`home.file.<name>.source` で指定したファイルのシンボリックリンクを `~/` に作成します。

以下の例では、`~/.config/home-manager/git/.gitconfig` が `~/.gitconfig` として配置されます。

```nix:~/.config/home-manager/home.nix
  home.packages = with pkgs; [
    git
  ];

  # home.nix からの相対パスを指定
  home.file = {
    ".gitconfig".source = ./git/.gitconfig;
  };
```


## 6.3 パッケージの設定ファイルの生成 programs.<package>

`programs.<package>` でソフトのインストールと設定ファイルを構築・配置できます。

以下の例では、Git の `user.name` と `user.email` が定義された設定ファイルが `~/.gitconfig` として配置されます。

```nix:~/.config/home-manager/home.nix
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


## 6.4 環境変数の設定 home.sessionVariables
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

# 7. アップデート
## 7.1 パッケージの更新
`~/.config/home-manager/` にて、以下のコマンドを実行します。

```bash:Bash
nix flake update nixpkgs
```

`flake.lock` が更新され、パッケージのビルドレシピが最新になります。

その後、以下のコマンドを実行すると、パッケージが更新されます。

```bash:Bash
home-manager switch
```


## 7.2 Home Manager 本体の更新
`~/.config/home-manager/` にて、以下のコマンドを実行します。

```bash:Bash
nix flake update home-manager
```

先程と同様に、`flake.lock` が更新され、Home Manager のビルドレシピが最新になります。

以下のコマンドで更新されます。

```bash:Bash
home-manager switch
```


### 7.3 本体更新の作業
Home Manager 本体を更新した際は、リリースノートを確認してください。

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


# 8. Home Manager のアンインストール
以下のコマンドを実行します。

```bash:Bash
home-manager uninstall
```


# 9. 補足
## 9.1 Home Manager の関数の調べ方
公式リファレンスに関数一覧が記載されています。

https://nix-community.github.io/home-manager/options.xhtml

`Option Search` というサイトを使うと調べやすいです。

https://home-manager-options.extranix.com/
