---
title: "2.5 Home Manager の実践テクニック"
---

# 1. この章でやること
この章では、Home Manager を運用していく中で出てくる「こうしたい」を解決するためのテクニックを紹介します。


# 2. ホーム直下以外に設定ファイルを配置する
`home.file` はホーム直下以外にもファイルを配置できます。
また、`xdg.configFile` を用いると `~/.config` 配下に置けるため便利です。

```nix:home.nix
{
  # ~/.gitconfig として配置
  home.file.".gitconfig".source = ./git/.gitconfig;

  # ~/.config/git/config として配置
  home.file.".config/git/config".source = ./git/.gitconfig;

  # XDG_CONFIG_HOME で指定されたディレクトリに配置
  # デフォルト値は .config/
  xdg.configFile."git/config".source = ./git/.gitconfig;
}
```


# 3. 設定ファイルの書き込み禁止を回避する
`home.file.<toolname>.source` で `.gitconfig` 等のシンボリックリンクを作成する場合、書き込み禁止なファイルとして配置されます。

:::message
例えば、**`git config --global` で値を書き込めない状態で配置されます**。

```bash:Bash
$ git config --global user.name "Nix"
error: could not lock config file /home/ryu/.gitconfig: Permission denied
```

:::


**対策として、`mkOutOfStoreSymlink` を用いると書き込み可能な状態でシンボリックリンクが作成されます**。

```nix:home.nix
{ config, ... }:
{
  home.file = {
    ".gitconfig".source = config.lib.file.mkOutOfStoreSymlink "/home/ryu/work/dotfiles/home-manager/git/.gitconfig";
  };
}
```

これにより、`git config --global` で設定を変更できるようになります。

:::message
`config.lib.file.mkOutOfStoreSymlink` の仕様で、**絶対パス**を指定する必要があります。
:::

:::details 保守性を意識してコードを書いた場合
最初のうちは上記の書き方でいいと思います。

Nix に慣れた後「そういえば、もっと綺麗な書き方もあったな」と思い出す & 振り返っていただくため、Nix らしく書いたコードも提示します。

先ほどのコード、私が実際に使うならば以下のように書きます。

```nix:home-manager/home.nix
{ config, ... }:
let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  dotfilesDir = "/home/ryu/work/dotfiles/home-manager";
in
{
  home.file = {
    ".gitconfig".source = mkOutOfStoreSymlink "${dotfilesDir}/git/.gitconfig";
  };
}
```

このような書き方に至る過程を解説します。

----

`let-in` は Nix 言語における変数のスコープを定めるキーワードです。
`let` で変数を宣言・初期化した後、`in` で利用するイメージです。

`inherit` はコード記述を簡略化するために使われます。

```nix
let
  a = 1;
in
{
  # 普通に書く場合
  a = a;

  # 省略して書くことができる
  inherit a;
}
```

`inherit ()` と書く場合、以下のように使えます。

```nix
let
  x = {
    a = 1;
  };
in
{
  # 普通に書く場合
  a = x.a;

  # 省略して書くことができる
  inherit (x) a;
}
```

最初に提示したコードで解説すると以下のようになります。

```nix
# 普通に書くと長い
mkOutOfStoreSymlink = config.lib.file.mkOutOfStoreSymlink;

# 短く記述できる
inherit (config.lib.file) mkOutOfStoreSymlink;
```

----

Nix では `{<引数>}: <式>` という形式で関数を定義します。
つまり、先ほど作成した `git.nix` ファイル全体で 1 つの関数となっています。

```nix
# config が引数
{ config, ... }:

# 以降が式
{
  home.file = ...
}
```

関数の式の中では引数を参照できます。
そのため、以下のように `config` という変数を利用できます。

```nix
{ config, ... }:
let
  hoge = config.lib....
```

最初に提示したコードで解説すると以下のようになります。

```nix
# config が引数
{ config, ... }:

# これ以降が式
let
  # 関数の引数 config を式の中で利用している
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  # let で宣言した mkOutOfStoreSymlink を使用している
  home.file = {
    ".gitconfig".source = mkOutOfStoreSymlink ...
  };
}
```

----

最後に、`.gitconfig` などへの絶対パスの記述を楽にするため、固定的なパスは変数化しています。

```nix
dotfilesDir = "/home/ryu/work/dotfiles/home-manager";
```

----

ここまでの内容を全て使うと、以下のようになります。

```nix:~/.config/home-manager/home.nix
{ config, ... }:
let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  dotfilesDir = "/home/ryu/work/dotfiles/home-manager";
in
{
  home.file = {
    ".gitconfig".source = mkOutOfStoreSymlink "${dotfilesDir}/git/.gitconfig";
  };
}
```

>文字列の中で変数を展開したい場合、`${dotfilesDir}` と書きます。

:::


# 4. 設定ファイルの分割
`home.nix` にユーザー環境を定義していくと、次第にファイルが肥大化します。
このままでは可読性・保守性が低くなってしまいます。

そこで、**設定ファイルを分割すると管理が楽になります**。

----

例えば、以下のような `home.nix` があったとします。

```nix:home-manager/home.nix
{ config, pkgs, ... }:

{
  home.username = "ryu"; # ユーザー環境に依存
  home.homeDirectory = "/Users/ryu"; # ユーザー環境に依存
  home.stateVersion = "25.11"; # Home Manager のバージョンに依存

  home.packages = [
    vim
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "MyNixName";
        email = "MyEmail@example.com";
      };
    };
  };

  programs.zsh = ...

  programs.home-manager.enable = true;
}
```

仮に `programs.git` の記述が長くなった場合、Git だけの設定ファイルに分離すると管理しやすくなります。

```nix:home-manager/home.nix
{ config, pkgs, ... }:

{
  home.username = "ryu"; # ユーザー環境に依存
  home.homeDirectory = "/Users/ryu"; # ユーザー環境に依存
  home.stateVersion = "25.11"; # Home Manager のバージョンに依存

  home.packages = [
    vim
  ];

  programs.zsh = ...

  programs.home-manager.enable = true;
}
```

```nix:home-manager/git.nix
{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "MyNixName";
        email = "MyEmail@example.com";
      };
    };
  };
}
```

:::message
Home Manager の設定は任意の名前のファイル（`*.nix`）として記述できます。
`*.nix` を保存するフォルダも任意です。
:::

:::message alert
**エラーを防ぐため、`git.nix` を `git add` しておいてください**。
:::


`home.nix` と `git.nix` を Home Manager に読み込ませるには、大まかに 2 つ方法があります。


#### 4.1 `home.nix` で imports する（おすすめ）
以下のように記述すると、`git.nix` の内容を Home Manager 側で読み込めるようになります。

```diff nix:home-manager/home.nix
{ config, pkgs, ... }:

{
  home.username = "ryu"; # ユーザー環境に依存
  home.homeDirectory = "/Users/ryu"; # ユーザー環境に依存
  home.stateVersion = "25.11"; # Home Manager のバージョンに依存

+ imports = [
+   ./git.nix
+ ];

  home.packages = [
    vim
  ];

  programs.zsh = ...

  programs.home-manager.enable = true;
}
```


#### 4.2 `flake.nix` で modules として指定する
`flake.nix` の `homeConfigurations` が `home-manager switch` する際に参照される情報を定義しています。

**`modules = []` に読み込みたい `*.nix` を指定します**。

```diff nix:home-manager/flake.nix
  homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
-   modules = [ ./home.nix ];
+   modules = [
+     ./home-manager/home.nix
+     ./home-manager/git.nix
+   ];
  };
```

`modules` に `git.nix` を追加します。

```nix:home-manager/flake.nix
  modules = [
    ./home.nix
    ./git.nix
  ];
```

:::message
**どちらの方法でも `git.nix` を指定する際は、設定を記述しているファイル（`home.nix` or `flake.nix`）を起点とした相対パスを利用します（絶対パスも可）**。
:::

:::message
個人的には、`flake.nix` 側の記述をシンプルにできるので、`home.nix` で import する方法が好みです。
:::


# 5. 複数の PC の設定を管理する
**`home-manager switch` した際、コマンドを実行した環境に応じて、異なる `*.nix` を読み込ませることが可能です**。

以下のように記述します。

```nix:flake.nix
      homeConfigurations = {
        # Main desktop PC, Windows 11, WSL (Ubuntu 22.04.5 LTS)
        "ryu_trifolium@main" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            ./home/common.nix
            ./home/wsl.nix
          ];
        };
        # MacBook Pro M1
        "ryu@MacBook.local" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          modules = [
            ./home/common.nix
            ./home/mac.nix
          ];
        };
      };
```

詳細はこちらの記事をご確認ください。

https://zenn.dev/trifolium/articles/b3d88bbabcad2c


# 6. 世代管理とロールバック
Home Manager は `generations` という履歴を残します。
設定ミスで環境が壊れた場合、**前の状態に戻すことが可能です**。

```bash:Bash
home-manager switch --rollback
```

- 公式リファレンス > Using Home Manager > Rollbacks

https://nix-community.github.io/home-manager/index.xhtml#sec-usage-rollbacks

----

世代一覧を表示できます。

```bash:Bash
home-manager generations
```

<!-- cspell:disable -->

```bash:Bash
> home-manager generations                                                    
yyyy-mm-dd hh:mm : id 3 -> /nix/store/r18xhwqgcpqw9278280bl4qvk5ldg25g-home-manager-generation (current)
yyyy-mm-dd hh:mm : id 2 -> /nix/store/ycp9a0r6syzi2rk7gpjsqw94hkpw7iq3-home-manager-generation
yyyy-mm-dd hh:mm : id 1 -> /nix/store/5jw2l0q4w2n6f782gffjk6xx728l2xx1-home-manager-generation
```

特定の世代のロードも行えます。

`nix/store/...` の末尾に `activate` を付けて実行すると、特定の世代をロードできます。

```bash:Bash
/nix/store/r18xhwqgcpqw9278280bl4qvk5ldg25g-home-manager-generation/activate
```

<!-- cspell:enable -->

:::message
`activate` を直接実行する方法はレガシーな方法です[^1]。
今後、廃止される可能性があります。
:::

[^1]: 公式リリースノート > Release 25.11 > Highlights: https://nix-community.github.io/home-manager/release-notes.xhtml#sec-release-25.11
