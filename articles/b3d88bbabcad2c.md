---
title: "複数の Linux / Mac のユーザー環境を 1 レポジトリ + 1 コマンドで構築する（Nix 未経験者向け解説）"
emoji: "🐚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [nix, nixflakes, homemanager, dotfiles]
published: true
published_at: "2025-12-05 07:00"
---

# はじめに
**本記事では、備忘録を兼ねて、私が行っているユーザー環境の管理方法を解説します**。

複数の PC を使っていると、Git などをそれぞれ手作業でインストールしたり、`.gitconfig` をコピーして使いまわすのは面倒です。
かといって、WSL 用 / Mac 用と dotfiles を別々のレポジトリとして管理するのもこれまた面倒です。

そこで、**私は home-manager を利用してユーザー環境を管理しています**。
複数の Linux / Mac のユーザー環境を **1 レポジトリ + 1 コマンド** で構築できる状態になるように設定を組んでいます。

**本記事では、`git clone <dotfiles>` して `home-manager switch` するだけで、実行環境に合わせた設定ファイルを元にユーザー環境（Git 等の導入、`.gitconfig` の配置など）を構築できるように設定していきます**。

:::message
なお、本記事では **Nix 未導入の状態からユーザー環境を構築するまでを取り扱います**。
（新しい PC を買った際、自分が迷わず楽にコピペ操作できるように。）

ですので、**Nix を使った事が無い人でも気軽にお試しできるかと思います**。
:::


# 記事の流れ
以下の流れで進行していきます。

- 1. 新規環境の準備（WSL Ubuntu 22.04）
- 2. Nix、home-manager のインストール
- 3. home-manager の設定
- 4. ユーザー環境の適用
- 5. Mac と WSL の環境を同時に管理

本記事では、サンプル環境として新しく WSL で Ubuntu を入れ、環境を構築していきます。
WSL のユーザー環境が完成した後、Mac のユーザー環境も同時に管理するための設定をしていきます。

:::message
**すでに home-manager でユーザー環境を管理している方へ**。

`5. Mac と WSL の環境を同時に管理`までは知っている内容だと思うので流し読みでも問題ありません。

ただし、本記事では `flake.nix` を用いて home-manager を導入しているので、`nix-channel` で導入している方はご注意ください。

Flakes での導入方法は以下の記事をご参照ください。
:::

https://zenn.dev/trifolium/articles/dafb565c778ed5

https://nix-community.github.io/home-manager/index.xhtml#ch-nix-flakes


# 検証環境
Windows 11 WSL2 Ubuntu 22.04 を利用します。
詳細は長いので折り畳み。

<!-- cspell:disable -->

:::details 検証環境
Windows の情報。

```powershell:PowerShell
> systeminfo | findstr /B /C:"OS"
OS 名:                      Microsoft Windows 11 Home
OS バージョン:              10.0.26100 N/A ビルド 26100
# 省略

> wsl --version
WSL バージョン: 2.6.1.0
カーネル バージョン: 6.6.87.2-1
WSLg バージョン: 1.0.66
MSRDC バージョン: 1.2.6353
Direct3D バージョン: 1.611.1-81528511
DXCore バージョン: 10.0.26100.1-240331-1435.ge-release
Windows バージョン: 10.0.26100.7171
```

WSL Ubuntu の情報。

```bash:bash
$ cat /etc/os-release | grep PRETTY_NAME
PRETTY_NAME="Ubuntu 22.04.5 LTS"

# Nix、home-manager 導入後
$ nix --version
nix (Determinate Nix 3.13.2) 2.32.4
$ home-manager --version
26.05-pre
```

:::

<!-- cspell:enable -->

# 1. 新規環境の準備（WSL Ubuntu 22.04）
WSL で Ubuntu-22.04 を入れます。

```powershell:PowerShell
> wsl --install Ubuntu-22.04
# ...
Enter new UNIX username: ryu_trifolium
# ...
```

これ以降は WSL 内での操作となります。

```powershell:PowerShell
wsl -d Ubuntu-22.04
```

:::message
**いきなり Nix を入れるのは怖いと思うので、（WSL なら）新しい環境を使うか、既存環境をコピーしてから実施してください**。
ちなみに、私は初見時に Nix 用の環境を作りました。当時の記事は以下です。
:::

https://zenn.dev/trifolium/articles/d695cebc50a888


# 2. Nix、home-manager のインストール
## 2.1 Nix
ワンコマンドで楽に Nix を導入できる Determinate Systems のインストーラーを利用します。

https://github.com/DeterminateSystems/nix-installer

以下のコマンドを実行します。
途中で実行していいか聞かれるので、`y` を入力します。

```bash:bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
```

Nix コマンドを有効化するために shell を再起動するか、以下のコマンドを実行します。

```bash:bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

:::details 実行ログ
長いので折り畳み。

```bash:bash
$ curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
info: downloading installer
 INFO nix-installer v3.13.2
`nix-installer` needs to run as `root`, attempting to escalate now via `sudo`...
[sudo] password for ryu_trifolium:
 INFO nix-installer v3.13.2
Nix install plan (v3.13.2)
Planner: linux

Configured settings:
* determinate_nix: true

Planned actions:
* Create directory `/nix`
* Install Determinate Nixd
* Extract the bundled Nix (originally from /nix/store/i130n1p2i0l1kyx0xa9fcn4d8jjrjb4b-nix-binary-tarball-3.13.2/nix-3.13.2-x86_64-linux.tar.xz) to `/nix/temp-install-dir`
* Create a directory tree in `/nix`
* Synchronize /nix/var ownership
* Move the downloaded Nix into `/nix`
* Synchronize /nix/store ownership
* Create build users (UID 30001-30032) and group (GID 30000)
* Setup the default Nix profile
* Place the Nix configuration in `/etc/nix/nix.conf`
* Configure the shell profiles
* Configure the Determinate Nix daemon
* Remove directory `/nix/temp-install-dir`


Proceed? ([Y]es/[n]o/[e]xplain): y
 INFO Step: Create directory `/nix`
 INFO Step: Install Determinate Nixd
 INFO Step: Provision Nix
 INFO Step: Create build users (UID 30001-30032) and group (GID 30000)
 INFO Step: Configure Nix
 INFO Step: Create directory `/etc/tmpfiles.d`
 INFO Step: Configure the Determinate Nix daemon
 INFO Step: Remove directory `/nix/temp-install-dir`
Nix was installed successfully!
To get started using Nix, open a new shell or run `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`
```

:::


## 2.2 home-manager
公式マニュアルの「Nix Flakes - Standalone setup」に従ってインストールします。

https://nix-community.github.io/home-manager/index.xhtml#ch-nix-flakes

以下のコマンドを実行します。

```bash:bash
nix run home-manager/master -- init
```

すると、`/home/ryu_trifolium/.config/home-manager/` フォルダの中に `home.nix` と `flake.nix` が生成されます。


# 3. home-manager の設定
`home.nix` にユーザー環境の設定を記述します。
`flake.nix` にどの `.nix` ファイルを読み込むかを記述します。

任意のエディターでファイルを編集していきます。

```bash:bash
cd /home/ryu_trifolium/.config/home-manager
code .
```

## 3.1 home.nix
自動生成された `home.nix` には `# コメント` で設定方法が書かれていますので、興味がある方は読んでみてください。

ここでは、Git と Bash、及び、`.gitconfig`、`.bashrc`、`.profile` を設定します。

また、解説のために `GREETING` という環境変数も設定しています。

```nix:home.nix
{ config, pkgs, ... }:

{
  home.username = "ryu_trifolium";
  home.homeDirectory = "/home/ryu_trifolium";

  home.stateVersion = "25.11";

  home.packages = [
    pkgs.git
    pkgs.bash
  ];

  home.file = {
    ".gitconfig".source = ./git/.gitconfig;
    ".bashrc".source = ./bash/.bashrc;
    ".profile".source = ./bash/.profile;
  };

  home.sessionVariables = {
    GREETING = "Hello Nix";
  };

  programs.home-manager.enable = true;
}
```

以下、細かい設定方法を解説していきます。

### 3.1.1 ユーザー、バージョン情報

```nix:home.nix
  home.username = "ryu_trifolium";
  home.homeDirectory = "/home/ryu_trifolium";

  home.stateVersion = "25.11";
```

ここは自動生成されたままで問題ありません。

home-manager をアップデートする際は、`stateVersion` を更新します。
どの値に更新すべきはリリースノートを確認してください。

https://nix-community.github.io/home-manager/release-notes.xhtml

なお、アップデート方法は後ほど解説します。

### 3.1.2 ツールの管理

```nix:home.nix
  home.packages = [
    pkgs.git
    pkgs.bash
  ];
```

ここにユーザー環境で利用したいツールを記述します。

利用可能なツールは NixOS Search - Packages で検索できます。
NixOSnixpkgs レポジトリには約 10 万のツールが登録されているので、大抵のツールは見つかるかと思います。

https://search.nixos.org/packages

##### 検索例
サイトを開き、検索欄に `vim` と記入します。
Channel は unstable を選択します。

>Channel の説明は割愛しますが、NixOS を使っていないなら unstable でいいです。

vim（青色文字になってる部分）をクリックし、`How to install vim?` に記載されているコマンドを確認します。
`nix-shell -p vim` これの -p 以降に書かれている文字列を `home.nix` に記述すれば、vim を導入できます。

![検索例](/images/b3d88bbabcad2c/b3d88bbabcad2c-2025-12-4.webp)

Nix はプラットフォームに合わせたツールの自動的に導入をしてくれますが、ツールによっては未対応のプラットフォームもあります。
M1 Mac なら `aarch64-darwin` といったように、自身の PC が対応しているか念のため確認してください。

一般的な Windows WSL 環境（`x86_64-linux`）ならほとんどの場合対応しています。
M1 Mac（`aarch64-darwin`）は時々対応していないツールがある印象です。
それ以外は未使用なので分かりませんが、サポートの手厚さは `x86_64-linux` > `aarch64-darwin` > その他、という印象です。

![対応プラットフォーム](/images/b3d88bbabcad2c/b3d88bbabcad2c-2025-12-4_2.webp)


:::details pkgs.git の書き方について
他の方の設定を見ると、以下の様に書かれている場合があるかもしれません。

```nix:home.nix
  home.packages = with pkgs; [
    git
    bash
  ];
```

これは以下と同じ意味です。

```nix:home.nix
  home.packages = [
    pkgs.git
    pkgs.bash
  ];
```

:::

### 3.1.3 設定ファイルの管理

```nix:home.nix
  home.file = {
    ".gitconfig".source = ./git/.gitconfig;
    ".bashrc".source = ./bash/.bashrc;
    ".profile".source = ./bash/.profile;
  };
```

ここで設定ファイルを指定できます。
`.gitconfig` として `./git/.gitconfig` にあるファイルを利用する、といった意味合いになります。

どのファイルを使用するかは `home.nix` からの相対パスで指定します。

私の場合、Git は普段使いしている `.gitconfig` をコピペしました。

Bash は既にある `~/.bashrc` をコピーしました。
なお、このままだと home-manager が設定する環境変数が Bash に反映されないので、`.bashrc` に設定を追加します。

```bash:bash
$ mkdir bash
$ cp ~/.bashrc bash/.bashrc
$ cat << 'EOF' >> bash/.bashrc

# for home-manager
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
EOF
```

```:フォルダ構成
~/.config/home-manager/
├── bash
│   ├── .bashrc
│   └── .profile
├── flake.nix
├── git
│   └── .gitconfig
└── home.nix
```

設定ファイルの指定方法は複数ありますので、他の方法が気になる方はこちらをご覧ください。

https://zenn.dev/trifolium/articles/642043cbae5f21

:::message
**Bash 等のシェルを home-manager で「管理しない」場合、シェルの設定を書き加える必要があります**。

```:~/.profile
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
```

参考：[公式リファレンス Installing Home Manager - Standalone installation - 4.](https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone)

:::

:::details 技術的に細かい補足
`. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"` を `.profile` に追記するのが公式の解説ですが、WSL だと再ログインしないと環境が反映されないので不便です。
なので、`.bashrc` に記載しました。

また、調べたところ `programs.bash.bashrcExtra` や `programs.bash.profileExtra` といったオプションがありました。
これらを使えば `. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"` を追加する必要はないかもしれません。

>実際に試していないので、確証はありません。

今回は極力シンプルな見た目にしたかったので、あえて `home.file.".profile".source` を使う方法にしました。

:::


### 3.1.4 環境変数の管理

```nix:home.nix
  home.sessionVariables = {
    GREETING = "Hello Nix";
  };
```

上記の様に環境変数を設定できます。


## 3.2 flake.nix
自動生成された状態のままで問題なく動きます。

なお、`system = "x86_64-linux"` や `homeConfigurations."ryu_trifolium"` といった部分は実行環境に合わせて自動的に設定されます。

>記事後半で WSL と Mac の環境を 1 つの `flake.nix` で管理するとき、この辺りを手動で編集します。

```nix:flake.nix
{
  description = "Home Manager configuration of ryu_trifolium";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."ryu_trifolium" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ ./home.nix ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
    };
}
```


# 4. ユーザー環境の適用
以下のコマンドを実行します。

```bash:bash
nix run home-manager/master -- init --switch -b backup
```

:::details コマンドの解説
公式リファレンスだと `nix run home-manager/master -- init --switch` が指定コマンドですが、`-b backup` を付け加えています。

今回、`.bashrc` を `~/.bashrc` からコピーしました。

`home.file.".bashrc".source = ./bash/.bashrc;` と記述した場合、home-manager は `~/` に `.bashrc` を配置しようとします。

そのため、このままだと既存ファイルと重複するため、エラーとなります。
`-b backup` を付けることで、元ファイルを `<filename>.backup` にリネームしてから、`.bashrc` を配置してくれます。
:::

次回からは、`home.nix` を更新したら以下のコマンドでユーザー環境を更新できます。

```bash:bash
home-manager switch
```

## 4.1 home-manager の更新、ツールの更新
home-manager 本体、及び、home-manager で導入するツールのバージョンを更新する場合、以下のコマンドを実行します。

`home-manager/flake.nix` があるディレクトリで実行してください。

```bash:bash
nix flake update
```

```bash:bash
# home-manager のみを更新する場合
$ nix flake lock --update-input home-manager

# home-manager で導入するツールのみを更新する場合
$ nix flake lock --update-input nixpkgs
```


# 5. Mac と WSL の環境を同時に管理
先ほど作成した WSL 環境に加えて、Mac 環境も同時に管理する、というストーリーを想定します。

以下の流れで作業していきます。

- dotfiles レポジトリの準備
- 共通した設定を定義したファイルの作成（`common.nix`）
- 環境独自の設定を定義したファイルの作成（`wsl.nix`、`mac.nix`）
- 各環境の `USER` と `HOSTNAME` を確認
- `flake.nix` を編集
- `home-manager switch` で反映

```bash:フォルダ構成
home-manager/
├─ home/
│   ├─ common.nix
│   ├─ mac.nix
│   └─ wsl.nix
├─ flake.nix
├─ git/
├─ bash/
└─ zsh/
```


## 5.1 dotfiles レポジトリの準備
先ほど作業した `~/.config/home-manager/` を Git 管理します。

フォルダ内で直接 Git 管理してもいいですし、私は `~/work/dotfiles` で管理して、`dotfiles/home-manager` から `.config/home-manager` にシンボリックリンクを張っています。
お好きな方法でいいかと思います。


## 5.2 共通した設定を定義したファイルの作成

`home.nix` に記述する設定の中で、各環境で共通する要素のみを抜き出したファイル `common.nix` を作成します。

```diff bash:フォルダ構成
 home-manager/
 └─ home/
+     └─ common.nix
```

<!-- cspell:disable -->

```nix:common.nix
{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    git
  ];

  home.file = {
    ".gitconfig".source = ../git/.gitconfig;
  };
}
```

<!-- cspell:enable -->

## 5.3 環境独自の設定を定義したファイルの作成
WSL と MacBook 専用の設定ファイル `wsl.nix`、`mac.nix` を作成します。

`home.username` と `home.homeDirectory` は環境に合わせた値を指定してください。

```diff bash:フォルダ構成
 home-manager/
 └─ home/
      ├─ common.nix
+     ├─ mac.nix
+     └─ wsl.nix
```

```nix:wsl.nix
{ config, pkgs, ... }:

{
  home.username = "ryu_trifolium";
  home.homeDirectory = "/home/ryu_trifolium";

  home.packages = with pkgs; [
    bash
    # その他 WSL でのみ使うツールを指定
  ];

  home.file = {
    ".bashrc".source = ../bash/.bashrc;
    ".profile".source = ../bash/.profile;
  };
}
```

```nix:mac.nix
{ config, pkgs, ... }:

{
  home.username = "ryu";
  home.homeDirectory = "/Users/ryu";

  home.packages = with pkgs; [
    zsh
    # その他 Mac でのみ使うツールを指定
  ];

  home.file = {
    ".zshrc".source = ../zsh/.zshrc;
    ".profile".source = ../zsh/.profile;
  };
}
```


## 5.4 各環境の `USER` と `HOSTNAME` を確認
以下のコマンドは筆者の例です。
次の作業で利用するのでメモしておきます。

```bash:bash WSL 環境
$ echo $USER
ryu_trifolium

$ hostname
main
```

```zsh:zsh Mac 環境
$ echo $USER
ryu

$ hostname
MacBook.local
```

:::message
もしも、環境間で `USER@HOSTNAME` の文字列が同じであった場合、環境の区別ができるように変更してください。
:::


## 5.5 `flake.nix` を編集
`flake.nix` にて `homeConfigurations.USER@HOSTNAME` と記述することで、特定の環境用の設定を指定できます。
例えば、私の WSL 環境の場合は以下の様にします。

```nix
# USER = ryu_trifolium、HOSTNAME = main
homeConfigurations."ryu_trifolium@main" = home-manager.lib.homeManagerConfiguration {
  # 自身の環境のシステムを指定、M1 Mac なら aarch64-darwin
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  # 読み込む設定ファイルを指定
  modules = [
    ./home/common.nix
    ./home/wsl.nix
  ];
};
```

`flake.nix` のコード例は以下の通りです。

```diff bash:フォルダ構成
 home-manager/
 ├─ home/
 │   ├─ common.nix
 │   ├─ mac.nix
 │   └─ wsl.nix
+└─ flake.nix
```

```nix:flake.nix
{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }:
    {
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
    };
}
```

:::message
**`homeConfigurations` の仕様については後ほど補足解説します**。
:::

## 5.6 環境の反映
以下のコマンドで環境を更新できます。

コマンド実行環境の `USER` と `HOSTNAME` に一致する `homeConfigurations` を自動的に選択して読み込んでくれます。

```bash:bash
home-manager switch
```

今回だと、WSL にて実行しているので、`wsl.nix` と `common.nix` に書かれた設定が反映されます。


## 5.7 Mac にてユーザー環境を構築
Mac に Nix が無いと仮定した場合、以下の数コマンドでユーザー環境の構築が終わります。

```zsh:zsh
# Nix をインストール
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate

# home-manager をインストール
nix run home-manager/master -- init --switch

# ~/.config/home-manager/ の中身を dotfiles で管理している home-manager/ で置き換え
git clone <your_dotfiles>

# 環境を反映
home-manager switch
```


# おわりに
以上で設定は完了です。

「パッケージマネージャー Nix」というと、純粋関数型言語である「Nix 言語」で設定を記述する必要があり、難しそうな雰囲気があります。
**しかし、home-manager でユーザー環境を管理する程度ならそこまで敷居が高くないのだと、今回の例で伝わっていれば嬉しいです**。

余談ですが、Flakes の devShell という機能を使えば、似たような書き方で開発環境の構築もできたりします。

```nix:flake.nix の一部
devShells.default = pkgs.mkShell {
  packages = [
    pkgs.terraform
    pkgs.azure-cli
    pkgs.go-task
  ];
};
```

**興味が湧いた方は、以下の本が大変分かりやすいので読んでみてください**。

https://zenn.dev/asa1984/books/nix-introduction

https://zenn.dev/asa1984/books/nix-hands-on

---

なお、まだ dotfiles の管理を十分にブラッシュアップできていないと思っているので、「これおかしくね？」という部分がありましたらコメントいただけますと幸いです。

---

:::message
**これ以降は備忘録を兼ねた解説となりますので、興味のある方のみお読みください**。
:::

# （参考）homeConfigurations について
homeConfigurations の詳細について、人力 & AI で検索したのですが、公式のリファレンスを見つけられませんでした。

以下は 2022 年の古いスレッドですが、ドキュメントには書かれていないロジックだとコメントされており、私と同じ状況でした。

>It should be explained in the manual: https://nix-community.github.io/home-manager/index.html#ch-nix-flakes
The extra logic around managing user+hostname has gone undocumented though. The scripts for this are easy to read if you need more detail.

https://discourse.nixos.org/t/get-hostname-in-home-manager-flake-for-host-dependent-user-configs/18859

ということで、ソースコードを見てきました。
どうやら `home-manager switch` コマンドの機能のようです。

**以下の内容は私の推測ベースなので話半分でお読みください**。

[こちらのファイル：home-manager/home-manager](https://github.com/nix-community/home-manager/blob/master/home-manager/home-manager) から抜粋した以下のコードが件のロジックかと思われます。

<!-- cspell:disable -->

```shell:home-manager
#!@bash@/bin/bash
# 省略...
function setFlakeAttribute() {
# 省略...
  local name="$USER"
  # Check FQDN, long, and short hostnames; long first to preserve
  # pre-existing behaviour in case both happen to be defined.
  for n in "$USER@$(hostname -f)" "$USER@$(hostname)" "$USER@$(hostname -s)"; do
      if [[ "$(nix eval "$flake#homeConfigurations" --apply "x: x ? \"$(escapeForNix "$n")\"")" == "true" ]]; then
          name="$n"
          if [[ -v VERBOSE ]]; then
              echo "Using flake homeConfiguration for $name"
          fi
      fi
  done
# 省略...
```

<!-- cspell:enable -->

`function doSwitch()` にて `function setFlakeAttribute()`、`function doBuildFlake()` の順で呼び出されています。

`function setFlakeAttribute()` の処理から、以下のルールのようです。

- `flake.nix` の `homeConfigurations` の名前が以下の 3 パターンと一致するかを判定
  - `$USER@$(hostname -f)`
  - `$USER@$(hostname)`
  - `$USER@$(hostname -s)`
- 一致したら名前を `name` に代入
- -> 以降の処理で `homeConfiguration.name` の情報を利用

この仕組みによって、環境の `USER` と `HOSTNAME` を自動で読み取って、読み込む設定ファイルを切り替えてくれているようです。


# （参考）他の方法
今回の方法を見つける過程で他の方法も検討しました。
備忘録を兼ねて、簡単なメモを残しておきます。

方法 3 をより楽に実施できないかと調べた結果、今の方法に行きついた次第です。

#### 1. dotfiles レポジトリを OS 毎に作り、`home.nix` を用意する

- WSL と Mac で共通した設定を使いまわせない、管理コストが大きい


#### 2. 単独の dotfiles レポジトリで `home.nix` を用意し、if 文で頑張る

- 美しくない（主観）
  - 環境ごとの記述が混在するので可読性が悪いと感じる
- 参考：「OS ごとの分岐を書きたいのだけれど？」項

https://apribase.net/2023/08/22/nix-home-manager-qa/

#### 3. 単独の `home.nix` で複数のプラットフォームに対応する

- `home-manager switch --flake .#hoge-user --impure` コマンドが長く、`impure` になる
- 環境ごとに設定を分離できない
- 参考：「良い感じにしてみる」項

https://zenn.dev/ymat19/articles/beac3c1beccac4#%E8%89%AF%E3%81%84%E6%84%9F%E3%81%98%E3%81%AB%E3%81%97%E3%81%A6%E3%81%BF%E3%82%8B
