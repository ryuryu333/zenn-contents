---
title: "Home Manager の設定整理と実践テクニック"
---

# 1. この章でやること
この章では、Home Manager を運用していく中で出てくる「こうしたい」を解決するためのテクニックを紹介します。


# 2. dotfiles として管理する
ユーザー環境をバージョン管理するために `~/.config/home-manager` を Git 管理したくなるかと思います。

今後の利便性を考慮すると、`~/.config/home-manager` を直接 Git 管理せず、**`dotfiles` レポジトリの一部として管理する**のをお勧めします。

:::message
dotfiles に明確な定義はありませんが、一般的には、ホームディレクトリにある設定ファイル（`~/.gitconfig` 等）を意味します。

転じて、ユーザー環境を管理することを指す言葉でもあります。
:::


筆者の場合、`~/work/dotfiles/home-manager` で `~/.config/home-manager` の内容を管理しています。

----

`~/.config/home-manager` から `~/work/dotfiles/home-manager/flake.nix` に設定ファイルを移動した場合、`home-manager switch` はエラーとなります。

```bash:Bash
$ home-manager switch                
設定ファイルがありません。ファイルを /Users/ryu/.config/home-manager/home.nix に作ってください
```

**対処方法は 2 つです**。

1. **シンボリックリンクを作成する**

以下のように dotfiles 管理下の `flake.nix` を `~/.config/home-manager/flake.nix` としてリンクさせます。

```bash:Bash
ln -s ~/work/dotfiles/home-manager/flake.nix ~/.config/home-manager/flake.nix
```

これで従来のコマンドでユーザー環境を更新できます。

```bash:Bash
home-manager switch
```

2. **`--flake` オプションを使う**

`--flake <flake.nix までのパス>` と指定します。

例えば、`flake.nix` があるディレクトリ（`~/work/dotfiles/home-manager`）で以下のコマンドを実行すると、ユーザー環境を更新できます。

```bash:Bash
home-manager switch --flake .
```


# 3. 設定ファイルの分割
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

```nix:home-manager/modules/git.nix
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


`home.nix` と `git.nix` を Home Manager に読み込ませるには、大まかに 2 つ方法があります。


1. **`home.nix` で imports する**

以下のように記述すると、`git.nix` の内容を Home Manager 側で読み込めるようになります。

```nix:home-manager/home.nix
{ config, pkgs, ... }:

{
  home.username = "ryu"; # ユーザー環境に依存
  home.homeDirectory = "/Users/ryu"; # ユーザー環境に依存
  home.stateVersion = "25.11"; # Home Manager のバージョンに依存

  imports = [
    ./modules/git.nix
  ];

  home.packages = [
    vim
  ];

  programs.zsh = ...

  programs.home-manager.enable = true;
}
```


2. **`flake.nix` で modules として指定する**

`home-manager/flake.nix` ファイル後半に、`homeConfigurations."<username>" = ...` と書かれた行があるかと思います。

`homeConfigurations` が `home-manager switch` する際に参照される情報です。
**`modules = []` にて読み込む設定ファイルを指定します**。

初期状態では、以下のように `home.nix` が指定されています。

```nix:home-manager/flake.nix
homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  # Specify your home configuration modules here, for example,
  # the path to your home.nix.
  modules = [ ./home.nix ];

  # Optionally use extraSpecialArgs
  # to pass through arguments to home.nix
};
```

`modules` に `git.nix` を追加します。

```nix:home-manager/flake.nix
  modules = [
    ./home.nix
    ./modules/git.nix
  ];
```


# 3. 編集可能なリンク（mkOutOfStoreSymlink）
`home.file.toolname.source` で `.gitconfig` 等のシンボリックリンクを作成する場合、編集不可なファイルとして配置されます。
つまり、**`git config --global` で値を書き込めなくなります**。

`dotfiles/git/.gitconfig` を直接編集して、`home-manager switch` するのは面倒です。
そこで、「編集可能なリンク」にしておくと便利です。

```nix:~/.config/home-manager/home.nix
{ config, ... }:
{
  home.file = {
    ".gitconfig".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/git/.gitconfig";
  };
}
```

これにより、`git config --global` で設定を変更できるようになります。

:::message
`config.lib.file.mkOutOfStoreSymlink` の仕様で、**絶対パス**を指定する必要があります。
`${config.home.homeDirectory}` で homeDirectory を取得できます。
:::


# 4. 設定ファイルの置き方（xdg.configFile）
`home.file` はホーム直下以外にもファイルを配置できます。

また、`xdg.configFile` を用いると `~/.config` 配下に置けるため便利です。

```nix:~/.config/home-manager/home.nix
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

先ほど紹介した `mkOutOfStoreSymlink` と `xdg.configFile` を組み合わせると管理しやすいと思います。

```nix:~/.config/home-manager/home.nix
  xdg.configFile."git/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/git/.gitconfig";
```


# 5. unfree license ライセンスのパッケージの扱い方
nixpkgs にはライセンスの都合で **unfree** 扱いとなるパッケージがあります。
デフォルトでは利用できないため、許可を明示する必要があります。

:::details エラー例（vsocde）
`pkgs.vscode` を指定した状態で `home-manager switch` すると、以下のようなエラーとなります。

```bash:Bash
$ home-manager switch
error:
       … while calling the 'derivationStrict' builtin
         at «nix-internal»/derivation-internal.nix:37:12:
           36|
           37|   strict = derivationStrict drvAttrs;
             |            ^
           38|

       … while evaluating derivation 'home-manager-generation'
         whose name attribute is located at «github:nixos/nixpkgs/ffbc9f8»/pkgs/stdenv/generic/make-derivation.nix:541:13

       … while evaluating attribute 'buildCommand' of derivation 'home-manager-generation'
         at «github:nixos/nixpkgs/ffbc9f8»/pkgs/build-support/trivial-builders/default.nix:80:17:
           79|         enableParallelBuilding = true;
           80|         inherit buildCommand name;
             |                 ^
           81|         passAsFile = [ "buildCommand" ] ++ (derivationArgs.passAsFile or [ ]);

       … while evaluating the option `home.activation.checkFilesChanged.data':

       … while evaluating definitions from `/nix/store/any8bfqi1w7qqih45zzwf5azi9nzclyp-source/modules/files.nix':

       … while evaluating the option `home.file."Library/Fonts/.home-manager-fonts-version".onChange':

       … while evaluating definitions from `/nix/store/any8bfqi1w7qqih45zzwf5azi9nzclyp-source/modules/targets/darwin/fonts.nix':

       (stack trace truncated; use '--show-trace' to show the full, detailed trace)

       error: Package ‘vscode-1.107.1’ in /nix/store/i1cgqsz2xxfz8h43f1g1fa4w6m8mdb40-source/pkgs/applications/editors/vscode/vscode.nix:102 has an unfree license (‘unfree’), refusing to evaluate.

       a) To temporarily allow unfree packages, you can use an environment variable
          for a single invocation of the nix tools.

            $ export NIXPKGS_ALLOW_UNFREE=1

          Note: When using `nix shell`, `nix build`, `nix develop`, etc with a flake,
                then pass `--impure` in order to allow use of environment variables.

       b) For `nixos-rebuild` you can set
         { nixpkgs.config.allowUnfree = true; }
       in configuration.nix to override this.

       Alternatively you can configure a predicate to allow specific packages:
         { nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
             "vscode"
           ];
         }

       c) For `nix-env`, `nix-build`, `nix-shell` or any other Nix command you can add
         { allowUnfree = true; }
       to ~/.config/nixpkgs/config.nix.
```

:::

- すべて許可する場合

```nix:~/.config/home-manager/home.nix
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    vscode
  ];
```

- 特定のパッケージだけ許可する場合

```nix:~/.config/home-manager/home.nix
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "vscode"
    ];

  home.packages = with pkgs; [
    vscode
  ];
```

:::message
個人の好みだと思いますが、`allowUnfreePredicate` を用いて個別に許可を出す形式の方が宣言的なので個人的には好きです。
ただし、unfree なツールを追加するたびに編集が必要となります。
手軽さからか、`allowUnfree` を利用している例も多く見かける印象です。
:::


# 6. shellAliases の活用
シェルのエイリアスも管理できます。

```nix:~/.config/home-manager/home.nix
{
  programs.zsh = {
    enable = true;
    shellAliases = {
      gs = "git status";
    };
  };
}
```


# 7. 世代管理とロールバック
Home Manager は `generations` という履歴を残します。
設定ミスで環境が壊れた場合、**前の状態に戻すことが可能です**。

```bash:Bash
home-manager switch --rollback
```

- 公式リファレンス > Using Home Manager > Rollbacks

https://nix-community.github.io/home-manager/index.xhtml#sec-usage-rollbacks

---

世代一覧を確認し、特定の世代の環境をロードすることも可能です。

```bash:Bash
home-manager generations
```

```bash:Bash
> home-manager generations                                                    
yyyy-mm-dd hh:mm : id 3 -> /nix/store/r18xhwqgcpqw9278280bl4qvk5ldg25g-home-manager-generation (current)
yyyy-mm-dd hh:mm : id 2 -> /nix/store/ycp9a0r6syzi2rk7gpjsqw94hkpw7iq3-home-manager-generation
yyyy-mm-dd hh:mm : id 1 -> /nix/store/5jw2l0q4w2n6f782gffjk6xx728l2xx1-home-manager-generation
```

`nix/store/...` の末尾に `activate` を付けて実行します。

```bash:Bash
/nix/store/r18xhwqgcpqw9278280bl4qvk5ldg25g-home-manager-generation/activate
```

:::message
`activate` を直接実行する方法はレガシーな方法です[^1]。
今後、廃止される可能性があります。
:::

[^1]: 公式リリースノート > Release 25.11 > Highlights: https://nix-community.github.io/home-manager/release-notes.xhtml#sec-release-25.11

