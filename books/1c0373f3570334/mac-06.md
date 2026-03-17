---
title: "3.5 nix-darwin で Homebrew を管理する"
---

# 1. この章でやること
この章では、nix-darwin で Homebrew を管理し、パッケージをインストール・更新する方法を解説します。


:::message
Nixpkgs に登録されていないパッケージ（Home Manager で導入するのが大変なパッケージ）は Homebrew でインストールすると運用が楽になります。

かといって、Homebrew 単独で運用すると Nix でユーザー環境とシステム環境を管理する、という意図と実運用にズレが生じます。

**そのため、nix-darwin で Homebrew 経由のパッケージインストールを管理することをおすすめします**。
:::


# 2. 前提環境
Home Manager でユーザー環境を管理していることが前提です。
以下のようなフォルダ構成となっていることを仮定して解説していきます。

```:フォルダ構成
~/work/dotfiles/
├── flake.lock
├── flake.nix
├── nix-darwin/
│     ├── configuration.nix
│     └── ... # その他、home_manager.nix 等
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


# 3. 設定ファイルを追加する
Homebrew を nix-darwin で管理するための設定ファイルを作成します（保存場所、名前は任意）。

```diff:フォルダ構成
  ~/work/dotfiles/
  ├── flake.lock
  ├── flake.nix
  ├── nix-darwin/
  │     ├── configuration.nix
+ │     ├── homebrew.nix
  │     └── ...
  └── home-manager/
        ├── home.nix
        └── ...
```

## 3.1 nix-homebrew 用の設定
[nix-homebrew](https://github.com/zhaofengli/nix-homebrew) を利用すると、Homebrew 本体を nix-darwin で管理できます。

```nix:homebrew.nix
{
  nix-homebrew,
  ...
}:
{
  nix-homebrew = {
    enable = true;
    user = "ryu";
    enableRosetta = false;
    autoMigrate = true;
  };
}
```

:::message
**`autoMigrate` を有効にしておくと、既存の Homebrew から自動移行されます**。
多くの方は Homebrew が入っていると思うので、有効にしておくとよいでしょう。

**`enableRosetta` は Apple シリコン搭載の Mac 限定の設定です**。
古い Intel Mac でしか動かないパッケージを利用する場合、有効にしてください。
現在では、そのようなパッケージは少ないかと思うので、無効化した例を提示しています。
:::


## 3.2 nix-darwin の Homebrew 設定
nix-darwin には Homebrew を用いてパッケージをインストールするための設定（`homebrew.*`）が用意されています。

https://nix-darwin.github.io/nix-darwin/manual/#opt-homebrew.enable


```nix:homebrew.nix
{
  nix-homebrew,
  ...
}:
{
  nix-homebrew = {
    enable = true;
    user = "ryu";
    enableRosetta = false;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    user = "ryu";
  };
}
```


# 4. configuration.nix を編集する
先ほど作成した `homebrew.nix` を imports します。

```diff nix:configuration.nix
{
  self,
  ...
}:
{
  imports = [
    ./home_manager.nix
+   ./homebrew.nix
  ];

  # 既存の設定...
}
```


# 5. flake.nix を編集する
`inputs` にて nix-homebrew の情報源を定義します。

`outputs` にて引数として `nix-darwin` を追加し、`modules` に `home-manager.darwinModules.home-manager` を追加します。

また、`configuration.nix` で呼び出す `homebrew.nix` にて `nix-homebrew` を引数として利用したいので、`specialArgs` に `nix-homebrew` を追加します。


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
+   nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
+     nix-homebrew,
      ...
    }:
    {
      darwinConfigurations."MacBook" = nix-darwin.lib.darwinSystem {
        specialArgs = {
+         inherit self nix-homebrew;
        };
        modules = [
          ./nix-darwin/configuration.nix
          home-manager.darwinModules.home-manager
+         nix-homebrew.darwinModules.nix-homebrew
        ];
      };
    };
}
```


# 6. 既存の Homebrew からパッケージを転記する
nix-darwin で Homebrew を管理する仕組みが用意できました。
**環境を更新する前に、既存の Homebrew からパッケージ一覧を設定に反映させます**。

Homebrew で手動インストールした CLI ツールは `--installed-on-request` で抽出できます。

>`brew list` だと依存関係で自動インストールされたツールも混ざるため、移行対象の整理には不向きです。

GUI アプリは `brew list --cask` で一覧化できます。

```bash:Bash
brew list --installed-on-request
```

```bash:Bash
brew list --cask
```

表示されたパッケージを `homebrew.nix` にて `brews` / `casks` として定義していきます。
**nix-darwin では以下のように記述できます**。

```nix:homebrew.nix
{
  nix-homebrew,
  ...
}:
{
  nix-homebrew = ...;

  homebrew = {
    enable = true;
    user = "ryu";
    brews = [
     # brew install nginx
      "nginx"
      # brew install petere/postgresql/postgresql-common
      "petere/postgresql/postgresql-common"
    ];
    casks = [
      # brew install --cask microsoft-office
      "microsoft-office"
    ];
    taps = [
      # brew tap petere/postgresql
      "petere/postgresql"
      
      # URL を指定する書き方も可能（架空の URL なのでコメントアウト）
      # brew tap user/tap-repo https://user@bitbucket.org/user/homebrew-tap-repo.git
      # {
      #   name = "user/tap-repo";
      #   clone_target = "https://user@bitbucket.org/user/homebrew-tap-repo.git";
      # }
    ];
  };
}
```


# 7. 反映する
nix-darwin の環境を更新すると、Homebrew によるパッケージのインストール処理も実施されます。

```bash:Bash
sudo darwin-rebuild switch --flake .
```


# 8. 補足
## 8.1 パッケージの更新設定
Homebrew 管理下のパッケージの更新タイミングを設定できます。

**デフォルト設定だと、`brew upgrade` コマンドを手動実行した場合に更新されます**。
`sudo darwin-rebuild switch` した際、パッケージのインストールは行われますが、更新処理はされないので注意してください。

:::message
`sudo darwin-rebuild switch` 実行時、一時的に `HOMEBREW_NO_AUTO_UPDATE = 1` が設定された状態で、`brew bundle install --no-upgrade` が実行されます。
:::

なお、デフォルト設定では、手動で `brew` コマンド（`brew install`、`brew tap` 等）を実行した場合に自動更新が走ります。
そのため、意図せず更新してしまう可能性があります。

**以下のように設定すると、Nix（`flake.nix`）に近い運用が可能になります**。

```nix:homebrew.nix
  homebrew = {
    onActivation = {
      upgrade = true;  // デフォルト false
      autoUpdate = false;  // デフォルト false
    };
    global.autoUpdate = false;  // デフォルト true
  };
```

この設定では、`HOMEBREW_NO_AUTO_UPDATE=1` が環境変数としてセットされるため、手動で `brew` コマンドを実行しても自動更新されません。

明示的に `brew update` して formula（パッケージ定義）を更新した後、`sudo darwin-rebuild switch` することで、パッケージが最新バージョンに更新されます。


:::message
`nix flake update` して `flake.lock` を更新した後、環境を更新するとパッケージが更新される、という流れと似た運用になります。

**いつ更新するかが明確になり、かつ、コマンドの責務が分離できる（`brew update` がパッケージ定義の更新、`sudo darwin-rebuild switch` が定義に基づいたパッケージのインストール・更新）ので、個人的に好きな設定です**。
:::


## 8.2 homebrew.onActivation.cleanup
`uninstall` を指定すると、リストに記載していないパッケージは自動的にアンインストールされます。

デフォルト設定（`none`）の場合、リストに記載されていないパッケージはそのままです（アンインストールされません）。

```nix:homebrew.nix
  homebrew = {
    onActivation.cleanup = "uninstall";
  };
```

:::message
`uninstall` を指定した場合、`sudo darwin-rebuild switch` した際、`brew bundle install --cleanup` コマンドが実行されます。

**設定ファイル（`configuration.nix` 等）で宣言されていない（＝手動でインストールしたパッケージ）はアンインストールされるので、注意してください**。

**既存の Homebrew で入れたパッケージを nix-darwin 側に全て移してから、設定してください**。
:::


# 8.3 最終的な設定例・運用例

```nix:homebrew.nix
  homebrew = {
    enable = true;
    user = "ryu";

    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = true;
      # cleanup = "uninstall";  # Homebrew からの移行完了後に設定
    };

    brews = [
      # brew install nginx
      "nginx"
    ];
    casks = [
      # brew install --cask microsoft-office
      "microsoft-office"
    ];
  };
```

パッケージを追加する場合は、brews と casks のリストを編集した後、nix-darwin の環境を更新します。

```bash:Bash
sudo darwin-rebuild switch --flake .
```

Homebrew のパッケージを更新する場合、以下のコマンドを順に実行します。

```bash:Bash
brew update
sudo darwin-rebuild switch --flake .
```


## 8.4 nix-darwin での Homebrew 操作内容
nix-darwin が Homebrew を動かしてパッケージをインストールします。
内部では Homebrew の Bundle 機能を用いています。

**依存含めたパッケージのバージョン管理は Homebrew の機能に依存します**。
あくまでパッケージを Nix っぽく宣言的に記述して管理ができる程度に捉えてください。


:::details Homebrew パッケージの再現性を Nix で担保したい方
[brew-nix](https://github.com/BatteredBunny/brew-nix) を利用すると、Nix の仕組みでバージョンを固定できます。
ただし、ハッシュ値更新などが大変なので、強いこだわりがある場合のみお試しください。

>私は使っていません。
Homebrew で管理する（Nixpkgs にない）パッケージは大半が開発に利用しません。パッケージが揃えば十分と感じています。
Nix による再現性の恩恵よりも、Nix に起因したエラー発生リスクの方が高いと判断しました。
そもそも、brew-nix で管理したいパッケージならば、自分で Nixpkgs に登録・メンテした方が良いと思っています。

:::
