---
title: "nix-darwin で home-manager を管理する"
---

# 1. この章でやること
この章では、**nix-darwin に home-manager を組み込み**ます。

:::message
各ツールを別々に利用することも可能ですが、一括管理の方が運用が楽になります。
今は nix-darwin 用、home-manager 用の `flake.nix` がバラバラに存在する状態になっているかと思います。
これらを 1 つの `flake.nix` に集約するイメージです。
:::


# 2. 前提環境の整理
本書を 1 章から順に実施していることを前提とします。
具体的には、以下のようなフォルダ配置・ファイル構成となっていることを前提とします。

```:フォルダ構成
~/work/dotfiles/
├── configuration.nix
├── flake.lock
└── flake.nix

# or ~/work/dotfiles/home-manager/
~/.config/home-manager/
├── home.nix
├── flake.lock
├── flake.nix
└── ... # その他、git/.gitconfig 等
```

```nix:~/work/dotfiles/flake.nix
{
  description = "nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      ...
    }:
    {
      darwinConfigurations."<hostname>" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit self; };
        modules = [
          ./configuration.nix
        ];
      };
    };
}
```

```~/.config/home-manager/home.nix
{ config, pkgs, ... }:

{
  home.username = "ryu";  # 環境依存、読者の環境で自動生成された値を利用してください
  home.homeDirectory = "/Users/ryu";  # 環境依存、読者の環境で自動生成された値を利用してください

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "discord"
    ];
  
  home.stateVersion = "25.11"; # 本体バージョン依存、読者の環境で自動生成された値を利用してください

  home.packages = with pkgs; [
    git
    zsh
    discord
    # その他 Homebrew から移行したツール
  ];

  xdg.configFile."git/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/git/.gitconfig";

  home.file = {
    ".zshrc".source = ./zsh/.zshrc;
    ".zprofile".source = ./zsh/.zprofile;
  };

  programs.home-manager.enable = true;
}
```

:::message
注意。

本章での操作により、`~/.config/home-manager/flake.nix` を無くし、`~/work/dotfiles/flake.nix` に統合します。
そのため、home-manager 本体・管理下のツールのバージョンを固定している `flake.lock` も同様に `~/work/dotfiles/flake.lock` に変わります。

バージョン差が発生するリスクを抑えたい場合、本章の作業前に、home-manager 側と nix-darwin 側のロックファイルを更新してください。

```bash:Bash
nix flake update
```

:::


# 3. home-manager を inputs に追加

:::message
移行に伴う変更箇所が多いので、あえて段階的にコードを変更していきます。
本章の最後に `sudo darwin-rebuild switch` しますので、途中のセクションでは switch しないでください。
:::

nix-darwin を管理している `flake.nix` を編集します。

`flake.nix` に home-manager を追加します。

```nix:~/work/dotfiles/flake.nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
```


# 4. nix-darwin モジュールとして home-manager を追加する
`modules` として home-manager を追加します。

`<username>` と `<hostname>` は自身の環境に合わせて書き換えてください。

```nix:~/work/dotfiles/flake.nix
  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    {
      darwinConfigurations."<hostname>" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit self; };
        modules = [
          ./configuration.nix

          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users."<username>" = {
                imports = [
                ];
              };
            };
          }
        ];
      };
    };
```

:::details コードの補足
`useGlobalPkgs = true` とすると、nix-darwin が管理している nixpkgs の設定（`nixpkgs.config.allowUnfree ` 等）を home-manager が利用可能になります。

ツールのビルドに使う情報源（nixpkgs）やその設定（nixpkgs.config）を nix-darwin が一元管理し、nix-darwin の各モジュールが利用する、という方が責務の分離の観点で良いと思います。

---

`useUserPackages = true` とした場合、CLI で呼び出すコマンドに変化はありませんが、呼び出し元が変わります。

```bash:Bash
# false のとき
/Users/ryu/.nix-profile/bin/hello

# true のとき
/etc/profiles/per-user/ryu/bin/hello
```

元々、home-manager は nix-profile という Nix の機能を利用して、ユーザー環境で各種ツールを利用可能にしています。

一方、nix-darwin もユーザー環境のツールを管理する機能があります（`users.users.<name>.packages`）。
加えて、nix-darwin はシステム環境（all users）にツールを導入する機能もあります（`environment.systemPackages`）。

複数のユーザー環境へツールを配置しつつ、システム環境にも配置するとなった場合、nix-darwin の方が管理しやすいです。

しかし、home-manager にも明確な強みもあります。
具体的には、ツールの設定ファイルの生成・配置の簡易さ、Mac 以外の Linux（Windows WSL 含む）と設定を共有できる、といったメリットがあります。

そのため、home-manager を使いつつ、ツールをユーザー環境で利用可能にする部分は nix-darwin に任せる、といった方向性がバランスが良いです。

`useUserPackages = true` にすると、home-manager は nix-darwin の `users.users.<name>.packages` を用いて各ツールをユーザー環境に導入できるようになります。
これにより、home-manager でインストールしたツールも nix-darwin の枠組みで統一的に管理できます。

>ちなみに、インストール先（パス）が変わるので、home-manager 単体利用時にツールのパスを直接的に利用していた場合、壊れる可能性があります。

>本設定は公式推奨（将来的にデフォルトで true になる可能性あり）です。

:::


# 5. home-manager の設定ファイルを指定する
home-manager 単体で利用していた際の設定ファイル（`home.nix`）を流用することが可能です。

以下のように、`users."<username>"` に `home.nix` を代入します。

```nix:~/work/dotfiles/flake.nix
home-manager.darwinModules.home-manager
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users."<username>" = {
      imports = [
        ./home-manager/home.nix  # flake.nix からの相対パス
      ];
    };
  };
}
```


# 6. home-manager の設定ファイルを移動
もしも、`~/.config/home-manager` に `home.nix` 等を保存していた場合は `~/work/dotfiles/home-manager` に移動させます。

```:フォルダ構成例
~/work/dotfiles/
├── configuration.nix
├── flake.lock
├── flake.nix
└── home-manager/
      ├── home.nix
      └── ... # その他、git/.gitconfig 等
```

:::message
フォルダ構成は自由ですが、`flake.nix` や `home.nix` 内での相対パスが壊れていないか、適宜ご確認ください。
:::


# 7. nixpkgs の設定を configuration.nix に移す
本書は nixpkgs の設定を nix-darwin に移譲する（`useGlobalPkgs = true`）方針で解説を進めています。

そのため、home-manager 側に書いていた `nixpkgs` の設定を nix-darwin 側へ移します。
`home.nix` から該当設定を削除し、`configuration.nix` に追記してください。

- 設定例

```nix:~/work/dotfiles/configuration.nix
  # unfree を全て許可する場合
  nixpkgs.config.allowUnfree = true;

  # パッケージを指定して許可する場合
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "vscode"
      "discord"
    ];
```

:::message
書き方は `home.nix`、`configuration.nix` どちらも同じで `nixpkgs.~` と記述しますので、コピペで移せば大丈夫です。
:::


# 8. シェルの設定を変更
本書は home-manager で導入するツールのインストール先を nix-darwin の仕組みで管理する（`useUserPackages = true`）方針で解説を進めています。

そのため、home-manager 単体利用時のツールのパスを直書きしていた場合、修正する必要があります。

例えば、home-manager が生成する環境変数等を利用するために、シェルの profile に以下のような設定をしているはずです。

- zsh の場合

```:.zprofile
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
```

`$HOME/.nix-profile` ではなく `/etc/profiles/per-user/$USER` を利用する形に書き換えてください。

```:.zprofile
. "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
```


# 9. 反映する
設定を反映します。

```bash:Bash
sudo darwin-rebuild switch
```


# 10. ツールの追加方法
今までと同様に、`home.nix` を更新した後、`home-manager switch` の代わりに `sudo darwin-rebuild switch` を実行すると反映されます。
