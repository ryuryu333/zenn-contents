---
title: "nix-darwin で Home Manager を管理する"
---

# 1. この章でやること
この章では、nix-darwin に Home Manager を組み込みます。

:::message
各ツールを別々に利用できますが、一括管理の方が楽に運用できます。

現時点では、nix-darwin 用、Home Manager 用の `flake.nix` がバラバラに存在する状態になっているかと思います。
これらを 1 つの `flake.nix` に集約します。

----

本章の手順は [Home Manager 公式ドキュメントの Nix Flakes > nix-darwin module](https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-nix-darwin-module) に準拠しています。
:::


# 2. 前提環境
Home Manager でユーザー環境を管理していることが前提です。
詳細は第二部を参照ください。

以下のようなフォルダ・ファイル構成となっていることを仮定して解説していきます。

```:フォルダ構成
~/work/dotfiles/
├── configuration.nix
├── flake.lock
├── flake.nix
└── home-manager/  # or ~/.config/home-manager/
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

```nix:~/work/dotfiles/home-manager/flake.nix
{
  description = "Home Manager configuration of ryu";

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
      # 環境依存、読者の環境で自動生成された値を利用してください
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      user = "ryu";
    in
    {
      homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
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

`configuration,nix` や `home.nix` の中身は関係無いので提示しません。

:::message
**意図しないバージョンの変更に関する注意**。

本章での操作により、`~/work/dotfiles/home-manager/flake.nix` を削除し、`~/work/dotfiles/flake.nix` に統合します。
また、**Home Manager 本体・パッケージのバージョンを固定している `flake.lock` も同様に削除、`~/work/dotfiles/flake.lock` に置き換わります**。

バージョン差が発生するリスクを抑えたい場合、本章の作業前に、Home Manager 側と nix-darwin 側、双方のロックファイルを更新してください。

```zsh:Zsh
nix flake update
```

:::


# 3. Home Manager を inputs に追加

:::message
移行に伴う変更箇所が多いので、あえて段階的にコードを変更していきます。
本章の最後に `sudo darwin-rebuild switch` しますので、途中のセクションでは switch しないでください。
:::

nix-darwin を管理している `flake.nix` を編集します。

`flake.nix` に `home-manager` を追加します。

```diff nix:~/work/dotfiles/flake.nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
+   # Home Manager の情報をどこから取得するかを記述
+   home-manager = {
+     url = "github:nix-community/home-manager";
+     inputs.nixpkgs.follows = "nixpkgs";
+   };
  };
```


# 4. nix-darwin モジュールとして Home Manager を追加する
`modules` として Home Manager を追加します。

`<username>` と `<hostname>` は自身の環境に合わせて書き換えてください。

```diff nix:~/work/dotfiles/flake.nix
  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
+     # inputs で定義した home-manager を参照するために追加
+     home-manager
      ...
    }:
    {
      darwinConfigurations."<hostname>" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit self; };
        modules = [
          ./configuration.nix

+         # Home Manager を nix-darwin モジュールとして組み込む
+         home-manager.darwinModules.home-manager
+
+         # Home Manager モジュールの設定を記述
+         {
+           home-manager = {
+             useGlobalPkgs = true;
+             useUserPackages = true;
+             users."<username>" = {
+               imports = [
+               ];
+             };
+           };
+         }
        ];
      };
    };
```

:::details useGlobalPkgs について
`useGlobalPkgs = true` とすると、nix-darwin が管理している Nixpkgs の設定（`nixpkgs.config.allowUnfree` 等）を Home Manager が利用可能になります。

ツールのビルドに使う情報源（Nixpkgs）やその設定（`nixpkgs.config`）を nix-darwin が一元管理し、nix-darwin の各モジュールが利用する、という方が責務の分離の観点で良いと思います。
:::

:::details useUserPackages について
`useUserPackages = true` とした場合、CLI で呼び出すコマンドに変化はありませんが、呼び出し元が変わります。

```zsh:Zsh
> which git
# false のとき
/Users/ryu/.nix-profile/bin/git

# true のとき
/etc/profiles/per-user/ryu/bin/git
```

Home Manager は nix-profile という Nix の機能を利用して、ユーザー環境で各種パッケージを利用可能にしています。

一方、nix-darwin にもユーザー環境のパッケージを管理する機能があります（`users.users.<name>.packages`）。
加えて、nix-darwin はシステム環境（all users）にパッケージを導入する機能もあります（`environment.systemPackages`）。

`useUserPackages` でどちらの仕組みでパッケージを配置するかを制御できます。

----

**複数のユーザー環境へパッケージを配置しつつ、システム環境にも配置するとなった場合、nix-darwin の方が管理しやすいです**。

しかし、**Home Manager にも明確な強みもあります**。
具体的には、ツールの設定ファイルの生成・配置の簡易さ、Mac 以外の Linux（Windows WSL 含む）と設定を共有できる、といったメリットがあります。

そのため、パッケージのインストールや設定ファイルの配置は Home Manager に任せつつ、パッケージの配置は nix-darwin に任せる、といった責務の分離がお勧めです。

----

`useUserPackages = true` にすると、Home Manager は nix-darwin の `users.users.<name>.packages` を用いて各パッケージをユーザー環境へ導入できるようになります。
これにより、Home Manager でインストールしたパッケージも nix-darwin の仕組みで統一的に管理できます。

>ちなみに、インストール先（パス）が変わるので、Home Manager 単体利用時にパッケージのパスを直接的に利用していた場合、壊れる可能性があります。
>なお、本設定は公式推奨（将来的にデフォルトで true になる可能性あり）です。

:::


# 5. Home Manager の設定ファイルを指定する
Home Manager 単体で利用していた際の設定ファイル（`home.nix` など）を流用するできます。

以下のように、`users."<username>".imports` に `home.nix` を代入します。

```diff nix:~/work/dotfiles/flake.nix
home-manager.darwinModules.home-manager
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users."<username>" = {
      imports = [
+       ./home-manager/home.nix  # flake.nix からの相対パス
      ];
    };
  };
}
```


# 6. Home Manager の設定フォルダについて
もしも、`~/.config/home-manager` に `home.nix` 等を保存していた場合は `~/work/dotfiles/home-manager` に移動させてください。

```:フォルダ構成例
~/work/dotfiles/
├── configuration.nix
├── flake.lock
├── flake.nix
└── home-manager/
      ├── home.nix
      └── ... # その他、git/.gitconfig 等
```

今後、`~/work/dotfiles` に設定を集約するため、`~/work/dotfiles/home-manager` を利用することはありません。

そのため、もしも `~/work/dotfiles/home-manager` から `~/.config/home-manager` にシンボリックリンクを作成していた場合、削除してください。

>シンボリックリンクを残していても（おそらく）問題は起きないので、任意です。


# 7. Nixpkgs の設定を configuration.nix に移す
本書は Nixpkgs の設定を nix-darwin に移譲する方針（`home-manager.useGlobalPkgs = true`）で解説を進めています。

そのため、Home Manager 側に書いていた `nixpkgs` の設定を nix-darwin 側へ移します。
`home.nix` から該当設定を削除し、`configuration.nix` に追記してください。

- 設定例

```nix:~/work/dotfiles/configuration.nix
  # unfree を全て許可する場合
  nixpkgs.config.allowUnfree = true;

  # パッケージを指定して許可する場合
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "terraform"
    ];
```

:::message
書き方は `home.nix`、`configuration.nix` どちらも同じなので、コピペで移せば大丈夫です。
:::


# 8. シェルの設定を変更
本書は Home Manager で導入するツールのインストール先を nix-darwin の仕組みで管理する方針（`home-manager.useUserPackages = true`）で解説を進めています。

そのため、Home Manager 単体利用時のパッケージのパスを直書きしていた場合、修正する必要があります。

例えば、Home Manager が生成する環境変数等を利用するために、シェルの profile に以下のような設定をしているはずです。

- Zsh の場合

```:.zprofile
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
```

`$HOME/.nix-profile` ではなく `/etc/profiles/per-user/$USER` を利用する形に書き換えてください。

```:.zprofile
. "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
```

>詳細は [Home Manager 公式ドキュメントの Nix Flakes > nix-darwin module](https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-nix-darwin-module) を参照ください。


# 9. 反映する
設定を反映します。

```zsh:Zsh
sudo darwin-rebuild switch
```


# 10. 補足
## 10.1 パッケージの追加
今までと同様に、`home.nix` を更新した後、`home-manager switch` の代わりに `sudo darwin-rebuild switch` を実行すると反映されます。

```diff nix:~/work/dotfiles/home-manager/home.nix
  home.packages = with pkgs; [
    git
+   terraform
  ];
```

```zsh:Zsh
sudo darwin-rebuild switch
```


## 10.2 更新
`flake.nix` があるディレクトリ（`~/work/dotfiles`）で以下を実行すると、`flake.lock` が更新されます。

```zsh:Zsh
# パッケージ更新
nix flake update nixpkgs

# Home Manager 更新
nix flake update home-manager

# nix-darwin 更新
nix flake update nix-darwin

# 全てを更新
nix flake update
```

環境を更新すると、バージョンが最新になります。

```zsh:Zsh
sudo darwin-rebuild switch
```
