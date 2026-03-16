---
title: "nix-darwin のインストール"
---

# 1. この章でやること
この章では nix-darwin をインストールします。

:::message
手順は[公式ドキュメント > Getting started > Flakes](https://github.com/nix-darwin/nix-darwin) をベースにしています。
:::


# 2. 前提環境
**dotfiles フォルダに `flake.nix` がある前提です**。
既存の `flake.nix` を編集し、nix-darwin をインストールします。

```:フォルダ構成例
~/work/dotfiles/
├─ flake.lock
├─ flake.nix
└─ home-manager/
    └─ ...
```

:::message
**Home Manager と nix-darwin は別ツールですので、nix-darwin 単独でも利用できます**。

しかし、併用することでユーザー環境からシステム設定までを一括で管理できるので大変便利です。

どちらも複雑なツールです。
**Nix に慣れながら進めるという観点で、Home Manager -> nix-darwin と段階的に導入することをおすすめします**。

>nix-darwin と Home Manager を同時に入れることも可能ですが、Nix 固有の問題・ツール固有の問題・nix-darwin と Home Manager の連携面での問題、と落とし穴が多くなります。
初学者では問題の切り分けが困難となり、挫折する可能性が高いかと思います。
:::


# 2. configuration.nix の作成
`~/work/dotfiles` に nix-darwin 設定ファイル用のフォルダを用意し、その中に `configuration.nix` を作成します。

```diff:フォルダ構成
  ~/work/dotfiles/
  ├─ flake.lock
  ├─ flake.nix
+ ├─ nix-darwin/
+ │   └─ configuration.nix
  └─ home-manager/
      └─ ...
```

```nix:configuration.nix
{
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  nix.enable = false;
}
```

:::message
**`nixpkgs.hostPlatform` は Mac に合わせて変更してください**。
Intel CPU の Mac ならば `x86_64-darwin`、Apple シリコンならば `aarch64-darwin` です。

```zsh:Zsh
uname -m
```

筆者は M1 Mac なので、サンプルコードでは `aarch64-darwin` を記述しています。
:::

:::message
設定内容は次章以降で解説します。
一旦、最小限の設定だけを記述しています。
:::


# 3. flake.nix の編集
Home Manager と同様に、nix-darwin でも `flake.nix` でツール本体のバージョン管理やどの設定ファイル（`*.nix`）を利用するかを定義します。

```diff nix:flake.nix
  {
    description = "My dotfiles";

    inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };
+     nix-darwin = {
+       url = "github:nix-darwin/nix-darwin";
+       inputs.nixpkgs.follows = "nixpkgs";
+     };
    };

    outputs =
-     { nixpkgs, home-manager, ... }:
+     {
+       nixpkgs,
+       home-manager,
+       nix-darwin,
+       ...
+     }:
      let
        system = "aarch64-darwin";
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home-manager/home.nix ];
        };

+       darwinConfigurations."MacBook" = nix-darwin.lib.darwinSystem {
+         modules = [ ./nix-darwin/configuration.nix ];
+       };
      };
  }
```

:::message
**`darwinConfigurations."MacBook"` の部分は環境に合わせて書き換えてください**。

以下のコマンドで表示されるホスト名を記述してください。

```zsh:Zsh
scutil --get LocalHostName
```

```zsh:筆者の環境の場合
> scutil --get LocalHostName
MacBook
```

:::


# 4. インストール
`flake.nix` があるディレクトリで、以下を実行します。

```bash:Bash
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .
```


# 5. インストール確認
以下で確認します。

```zsh:Zsh
darwin-version
```

バージョンが表示されればインストール完了です。

```zsh:Zsh
> darwin-version
26.05.da529ac
```


# 6. 補足
## 6.1 アンインストール

```zsh:Zsh
sudo nix run nix-darwin#darwin-uninstaller
```


## 6.2 flake.nix の配置場所について
公式ドキュメントでは `/etc/nix-darwin` に `flake.nix` を作成・配置しています。

個人の好みですが、私は `/etc` のファイルを直接編集したり、Git 管理したくないです。
そのため、`~/work/dotfiles` で管理する方針にしています。
