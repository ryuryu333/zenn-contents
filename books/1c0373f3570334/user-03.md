---
title: "home-manager の基本的な使い方"
---

# 1. この章でやること
この章では **home-manager の基本的な使い方**を解説します。
まずはツールを 1 つだけ導入し、Homebrew との違いを確認します。


# 2. 最小構成で動かす
## 2.1 設定ファイルを開く
`home.nix` にユーザー環境の設定を記述します。

home-manager をインストールする際に自動生成された `~/.config/home-manager/home.nix` を開きます。

おそらく沢山のコメントによる解説が書かれている状態だと思います。
これから解説しますが、興味がある方は読んでみてください。

コメントを消すと以下のようになります。


```nix:~/.config/home-manager/home.nix
{ config, pkgs, ... }:

{
  home.username = "ryu"; # ユーザー環境に依存
  home.homeDirectory = "/Users/ryu"; # ユーザー環境に依存

  home.stateVersion = "25.11"; # home-manager のバージョンに依存

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


## 2.2 home.nix にツールを追加
ここでは例として **nixfmt** を追加します。

>`.nix` ファイル用のフォーマッターです。

`home.packages` に `nixfmt` を記述します。


```nix:~/.config/home-manager/home.nix
  home.packages = with pkgs; [
    nixfmt
  ];
```

:::details 記述方法の補足説明
Nix では、`pkgs.toolname` と書くとことで nixpkgs からツールのビルド情報を参照できます。
`pkgs` には参照する nixpkgs のブランチ・リビジョンの情報、ビルド対象のプラットフォーム情報（OS・CPU アーキテクチャ）などが含まれています。

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


# 3. 使えるようになったか確認

```bash:Bash
nixfmt --version
```

バージョンが表示されれば成功です。


# 4. ツールのアンインストール
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
**同じツールが入っていても問題ありません**。  
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


## 5.1 Homebrew と home-manager で同じツールを入れてみる

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

このように、**home-manager と Homebrew で管理された nixfmt が共存しています**。
`home-manager switch` を行うと、Nix 管理下の nixfmt が環境変数 `PATH` の先頭寄りに登録されるため、Homebrew ではなく **home-manager の nixfmt が優先して呼ばれる**状態になります。

そのため、**home-manager の設定から nixfmt を除外すれば、Homebrew の nixfmt が実行できます**。


## 5.2 依存ライブラリの扱い
nixfmt に紐づけられている shared libraries を otool で確認します。

**Homebrew 側では `/usr/lib/~`、home-manager 側では `nix/store/~` となっていることに注目してください**。 

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

:::message
`/usr/lib/libSystem.B.dylib` は Nix 管理外じゃないか！と思うかもしれませんが、これは仕様です。
libSystem は OS に強く紐づいているので例外的な処置となっています。

参考資料: [リンク](https://daiderd.com/2020/06/25/nix-and-libsystem.html)

このような例外を除き、**Nix は依存を含めてビルドします**。
そして、これら**依存ライブラリのバージョンはロックファイルで固定**されます。
:::

:::message
仮に、別のソフトで nixfmt と同じライブラリを必要となり、かつ、違うバージョンが要求された場合は、バージョン毎に `nix/store/hash-name-version` が作成されます。
同じライブラリをバージョン毎に用意するので、**ソフト A をインストールしたらソフト B の依存ライブラリが変更された、という状況を防げます**。

これは Nix の大きな魅力だと思います。
:::

::::::


# 6. home-manager でよく使う機能
## 6.1 ソフトの設定ファイルの生成・配置

:::message
**本セクションは実行せず、読むだけで大丈夫です**。
（既存の Git の設定ファイルと競合してしまうので。）

具体的な Git の移行作業は次章以降で解説します。
:::

代表的な書き方を 2 つピックアップして紹介します。

- シンボリックリンクの作成

`home.file.<name>.source` で指定したファイルのシンボリックリンクを `~/` に作成します。

```nix:~/.config/home-manager/home.nix
  home.packages = with pkgs; [
    git
  ];

  home.file = {
    ".gitconfig".source = ./git/.gitconfig;  # home.nix からの相対パスを指定
  };
```

- home-manager の関数経由で作成

`programs.<package_name>` でソフトのインストールと設定ファイルの構築・配置を行います。

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

参考までに、今回紹介しなかった別の方法はこちらの記事で解説しています。

https://zenn.dev/trifolium/articles/642043cbae5f21


:::message
保守性の観点でより良い書き方が気になる方は、次章をご確認ください。
:::


## 6.2 環境変数の設定
`home.sessionVariables` にて設定できます。

```nix:~/.config/home-manager/home.nix
  home.sessionVariables = {
    GREETING = "Hello Nix";
  };
```

```bash:Bash
$ echo $GREETING
Hello Nix
```


# 7. 補足
## 7.1 home-manager の関数の調べ方
公式リファレンスに関数一覧が記載されています。

https://nix-community.github.io/home-manager/options.xhtml

`Option Search` というサイトを使うと調べやすいです。

https://home-manager-options.extranix.com/


## 7.2 home-manager の更新
`~/.config/home-manager/` にて、以下のコマンドを実行します。

```bash:Bash
nix flake update
```

`flake.lock` が更新されます。

その後、以下のコマンドを実行すると、home-manager 本体とツールが更新されます。

```bash:Bash
home-manager switch
```

:::message
`flake.lock` はいわゆるロックファイルです。

[NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) という GitHub リポジトリに Nix で各ツールをビルドするためのレシピ（Derivation）が集約されています。

Nix は nixpkgs からビルドレシピを取得し、ツールのビルドを行います。
この際、ビルドレシピが同じならば同じビルド結果となるような仕組みになっています。

そのため、`flake.nix` で参照する nixpkgs のコミット位置を固定することで、ビルドされるツールのバージョンを固定できます。
:::

以下のコマンドで、更新対象を分けることができます。

```bash:Bash
# home-manager のみを更新する場合
nix flake lock --update-input home-manager

# home-manager で導入するツールのみを更新する場合
nix flake lock --update-input nixpkgs
```


### 7.2.1 home.nix の更新
home-manager 本体を更新した際は、リリースノートを確認してください。

リリースノートに `home.stateVersion` を更新する旨が記載されていた場合、`home.nix` にて指定された値に更新してください。

- 公式リファレンス リリースノート

https://nix-community.github.io/home-manager/release-notes.xhtml

```nix:~/.config/home-manager/home.nix
  home.stateVersion = "25.11";  # ここの値、必ずリリースノートを確認する
```

:::message
**`home.stateVersion` について**。

home-manager 更新時に、後方互換性を担保し、破壊的変更を防ぐための機能です[^1]。

必ずリリースノートを読み、既存の設定に悪影響を与えないか確認したうえで、リリースノートが指定した数値に変更してください。

**判断に迷う場合、現状の動作を維持したい場合は、無理に変更せず古い値のままで構いません。**
:::

[^1]: 公式リファレンス > Using Home Manager > Updating > State Version Management: https://nix-community.github.io/home-manager/index.xhtml#sec-upgrade-release-state-version

## 7.3 home-manager のアンインストール
以下のコマンドを実行します。

```bash:Bash
home-manager uninstall
```
