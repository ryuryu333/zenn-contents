---
title: "nix-darwin で Home Manager を管理する"
---

# 1. この章でやること
この章では、nix-darwin に Home Manager を組み込みます。

:::message
本章の手順は [Home Manager 公式ドキュメントの Nix Flakes > nix-darwin module](https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-nix-darwin-module) を参考にしています。
:::


# 2. 前提環境
Home Manager でユーザー環境を管理していることが前提です。
以下のようなフォルダ構成となっていることを仮定して解説していきます。

```:フォルダ構成
~/work/dotfiles/
├── flake.lock
├── flake.nix
├── nix-darwin/
│     └── configuration.nix
└── home-manager/
      ├── home.nix
      └── ... # その他、git/.gitconfig 等
```

```nix:~/work/dotfiles/flake.nix
{
  description = "My dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home-manager/home.nix ];
      };

      darwinConfigurations."MacBook" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit self;
        };
        modules = [ ./nix-darwin/configuration.nix ];
      };
    };
}
```


# 3. 設定ファイルを追加する
Home Manager 用の設定ファイルを定義します（保存場所、名前は任意）。

```diff:フォルダ構成
  ~/work/dotfiles/
  ├── flake.lock
  ├── flake.nix
  ├── nix-darwin/
  │     ├── configuration.nix
+ │     └── home_manager.nix
  └── home-manager/
        ├── home.nix
        └── ... # その他、git/.gitconfig 等
```

```nix:home_manager.nix
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."ryu" = ../home-manager/home.nix;
}
```

:::message
`"ryu"` は各自のユーザー名に書き換えてください。

```zsh:Zsh
echo $USER
```

----

**`imports` には `home_manager.nix` から `home.nix` への相対パスを記述します**。

:::


::::::details configuration.nix と見た目が違う？
`configuration.nix` と異なり、コード先頭に `{ self, ... }` が書いていません。

```nix:configuration.nix
{
  self,
  ...
}:
{
  # 色々な設定...
}
```

```nix:home_manager.nix
{
  # Home Manager 関連の設定...
}
```

`home_manager.nix` では、`self` などの引数は利用しません。
個人の好みの範疇ですが、関数（`<引数>:<式>`）にする必要性がないので、変数の集まり（Attribute Set）として定義しています。

----

以下のように書いても問題ありません。

```nix:home_manager.nix
{
  ...
}:
{
  # Home Manager 関連の設定...
}
```

:::message
Nix の魅力は記述の自由度が高いことです。
逆に言えば、上記のように書き手によってコードの見た目が変わります。

**慣れれば、コードから書き手の意図が読み取れるので、YAML や JSON などで書かれた設定よりも読みやすいです**。

しかし、初学者にとっては「同じ内容なはずのサンプルコードが人によって異なる」という状況になります...。
そのため、本書では折り畳みのテキストにて記述意図を解説するようにしています。
:::

::::::

:::details home-manager.users."ryu" について
Home Manager 単独で利用している際、`flake.nix` には以下のように記述しているかと思います。

```nix:flake.nix
  homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [ ./home-manager/home.nix ];
  };
```

この記述を nix-darwin に組み込む形で記述する際、どの `*.nix` を Home Manager の設定ファイルとして読み込むかを以下のように指定します。

```nix
home-manager.users."ryu" = ../home-manager/home.nix;
```

**注意が必要なのはパスの記述です**。
コードを書いている場所からの相対パスとなるので、自身のフォルダ構成に合わせて調整してください。

```:フォルダ構成
~/work/dotfiles/
├── flake.lock
├── flake.nix
├── nix-darwin/
│     ├── configuration.nix
│     └── home_manager.nix
└── home-manager/
      ├── home.nix
      └── ...
```

:::


::::::details useGlobalPkgs について
`useGlobalPkgs = true` とすると、nix-darwin が管理している Nixpkgs の設定（`nixpkgs.config.allowUnfree` 等）を Home Manager が利用可能になります。

:::message
ツールのビルドに使う情報源（Nixpkgs）やその設定（`nixpkgs.config`）を nix-darwin が一元管理できます。

**nix-darwin が管理し、配下のモジュール（Home Manager）が利用する、という関係性になるので、責務の分離の観点で良いと思います**。
:::


::::::


::::::details useUserPackages について
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


:::message
**複数のユーザー環境へパッケージを配置しつつ、システム環境にも配置するとなった場合、nix-darwin の方が管理しやすいです**。
:::

:::message
**Home Manager にも明確な強みがあります**。
ツールの設定ファイルの生成・配置の簡易さ、Mac 以外の Linux（Windows WSL 含む）と設定を共有できる、といったメリットがあります。
:::

**上記の特性を踏まえると、パッケージのインストールや設定ファイルの配置は Home Manager に任せ、出来上がったパッケージの配置は nix-darwin に任せる、といった方針で責務を分離するのがおすすめです**。

----

**`useUserPackages` でどちらの仕組みでパッケージを配置するかを制御できます**。

`useUserPackages = true` にすると、Home Manager は nix-darwin の `users.users.<name>.packages` を用いて各パッケージをユーザー環境へ導入できるようになります。
これにより、Home Manager でインストールしたパッケージも nix-darwin の仕組みで統一的に管理できます。

:::message alert
**インストール先（パス）が変わるので、Home Manager 単体利用時にパッケージのパスを直接的に利用していた場合、壊れる可能性があります**。
:::

なお、本設定は公式推奨（将来的にデフォルトで true になる可能性あり）です。

cf. [公式ドキュメント](https://nix-community.github.io/home-manager/index.xhtml#sec-install-nixos-module) Installing Home Manager > NixOS。

>By default packages will be installed to $HOME/.nix-profile but they can be installed to /etc/profiles if
home-manager.useUserPackages = true;
is added to the system configuration. This is necessary if, for example, you wish to use nixos-rebuild build-vm. This option may become the default value in the future.

**な ぜ か** nix-darwin modules ではなく NixOS modules の項目のみに `useUserPackages` の注釈が書かれています。

>大変分かりにくい...。
nix-darwin は NixOS の仕組みに似ているため、こういった方向性も共有されると私は思っています。
しかし、ドキュメントでは NixOS modules のみで言及されています。
nix-darwin だけ思想が異なるということは無いと思うのですが、明言してほしいものです...。

::::::

nix-darwin 用の設定（`home-manager.*`）の詳細は下記ドキュメントに記載されています。

https://nix-community.github.io/home-manager/nix-darwin-options.xhtml


# 4. configuration.nix を編集する
Home Manager 用の設定を追加します。

また、先ほど作成した `home_manager.nix` を imports します。

```nix:configuration.nix
{
  self,
  ...
}:
{
  # Home Manager の設定で必要
  users.users."ryu".home = "/Users/ryu";

  imports = [
    ./home_manager.nix
  ];

  # 既存の設定...
}
```


:::details users.users."ryu".home について
`users.users."ryu".home` を指定しない場合、`switch` した際にエラーが発生します。

```zsh:Zsh
> sudo darwin-rebuild switch --flake .
# ...
error: A definition for option `home-manager.users.ryu.home.homeDirectory' is not of type `absolute path'. Definition values:
       - In `/nix/store/irrzc95wr3yb4dr0whyg6n4hbr0mmq8f-source/nixos/common.nix': null
```

[Home Manager のドキュメント](https://nix-community.github.io/home-manager/index.xhtml#sec-install-nix-darwin-module)の Installing Home Manager > nix-darwin module に記述されています。

>to your nix-darwin configuration.nix file, which will introduce a new NixOS option called home-manager whose type is an attribute set that maps user names to Home Manager configurations.
For example, a nix-darwin configuration may include the lines
users.users.eve = {
  name = "eve";
  home = "/Users/eve";
};

なお、この記述は**な ぜ か** Nix Flakes > nix-darwin module の項目には書かれていません。
Flakes を使わないインストール方法の項目にのみ記述されていました。

>大変分かりにくい...。

:::


:::details imports について
**`flake.nix` にて `configuration.nix` と `home_manager.nix` を指定すればいいのでは、と思った方もいるかもしれません**。

上記のように設定すると、`flake.nix` で指定するモジュール数が減らせるので楽です。

個人の好みですが、私は `flake.nix` に「具体的にどのような設定を参照するか？」という情報は持たせたくないです。

`flake.nix` の責務はマシンごとにどの設定群を使うかの振り分けだと定義しています。
そして、設定群の具体を定義するのは `configuration.nix` としています。

```:イメージ
# As-Is
flake.nix
  -> configuration.nix
  -> home_manager.nix

# To-Be
flake.nix
  -> configuration.nix
    -> home_manager.nix
```

PC の数が増えた場合、この方がスッキリすると思います。

```:イメージ
flake.nix
  -> nix-darwin/MacBookProM1/configuration.nix
    -> home_manager.nix
    -> nixpkgs.nix
    -> system.nix
  -> nix-darwin/<my-new-Mac>/configuration.nix
    -> ...
```

:::


# 5. flake.nix を編集する
nix-darwin の `modules` に `home-manager.darwinModules.home-manager` を追加します。
これで、nix-darwin のシステムの一部として Home Manager が組み込まれます。

Home Manager を単独で利用していた頃のコードは残しておいても問題ありませんが、邪魔なので消します。


```diff nix:flake.nix
{
  description = "My dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
-   let
-     system = "aarch64-darwin";
-     pkgs = nixpkgs.legacyPackages.${system};
-   in
    {
-     homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
-       inherit pkgs;
-       modules = [ ./home-manager/home.nix ];
-     };

      darwinConfigurations."MacBook" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit self;
        };
        modules = [
          ./nix-darwin/configuration.nix
+         home-manager.darwinModules.home-manager
        ];
      };
    };
}
```

:::details 最終的な flake.nix
以下のようになります。

```nix:flake.nix
{
  description = "My dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    {
      darwinConfigurations."MacBook" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit self;
        };
        modules = [
          ./nix-darwin/configuration.nix
          home-manager.darwinModules.home-manager
        ];
      };
    };
}
```

:::


# 6. Nixpkgs の設定を configuration.nix に移行する
本書は Nixpkgs の設定を nix-darwin に移譲する方針（`home-manager.useGlobalPkgs = true`）で解説を進めています。
**そのため、Home Manager 側に書いていた `nixpkgs` の設定を nix-darwin 側へ移す必要があります**。

`home.nix` から該当設定を削除し、`configuration.nix` に追記してください。


```nix:configuration.nix
{
  self,
  ...
}:
{
  # unfree を全て許可する場合
  nixpkgs.config.allowUnfree = true;

  # パッケージを指定して許可する場合
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "terraform"
    ];

  # 既存の設定...
}
```

:::message
書き方は `home.nix`、`configuration.nix` どちらも同じなので、コピペで移せば大丈夫です。
:::


# 7. シェルの設定を変更
本書は Home Manager で導入するツールのインストール先を nix-darwin の仕組みで管理する方針（`home-manager.useUserPackages = true`）で解説を進めています。
**そのため、Home Manager 単体利用時のパッケージのパスを直書きしていた場合、修正する必要があります**。

**例えば、Home Manager が生成する環境変数のシェルのパスも変更する必要があります**。
Home Manager インストール時の作業で、シェルの profile に以下のような設定をしているはずです。

```:.zprofile
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
```

`$HOME/.nix-profile` ではなく `/etc/profiles/per-user/$USER` を利用する形に書き換えてください。

```:.zprofile
. "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
```

>詳細は [Home Manager 公式ドキュメントの Nix Flakes > nix-darwin module](https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-nix-darwin-module) を参照ください。


# 8. 反映する
設定を反映します。

```zsh:Zsh
sudo darwin-rebuild switch --flake .
```


# 9. 補足
## 9.1 パッケージの追加
今までと同様に、`home.nix` を更新した後、`home-manager switch --flake .` の代わりに `sudo darwin-rebuild switch --flake .` を実行すると反映されます。

```diff nix:~/work/dotfiles/home-manager/home.nix
  home.packages = with pkgs; [
    git
+   go-task
  ];
```

```zsh:Zsh
sudo darwin-rebuild switch --flake .
```

:::details 雑記
コマンドが長くて面倒だと思うので、[go-task](https://github.com/go-task/task) などのタスクランナーを使うと楽です。

私は以下のように書いています。

```yaml
  switch:
    desc: Switch environment
    platforms: [linux/amd64, darwin/arm64]
    cmds:
      - cmd: home-manager switch --flake .
        platforms: [linux/amd64]
      - cmd: sudo darwin-rebuild switch --flake .
        platforms: [darwin/arm64]

  update:
    desc: Update pkgs
    cmds:
      - cmd: nix flake update nixpkgs
      - cmd: echo "Update complete, run 'task' to switch"
```

:::


## 9.2 更新
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

:::message
nix-darwin、Home Manager 本体の更新は時間があるときに実施してください。
後方互換を維持する仕組みがあるとはいえ、予期せぬ挙動となる可能性もあります。

基本的には nixpkgs だけを更新しておけば良いと思います。
:::
