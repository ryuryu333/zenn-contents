---
title: "Flakes テンプレートを自作 & 公開する"
---

# 1. この章でやること
この章では `flake.nix` のテンプレートを自作し、公開する方法を解説します。


# 2. テンプレートを自作する
**公開されているテンプレートは便利ですが、（自分のニーズに対して）記述の過不足を感じるかもしれません**。
そのため、テンプレートを自作すると便利です。

ローカルに以下のようなフォルダを作成します。

```:フォルダ構成
~/work/nix-template/
├── basic
│   ├── .envrc
│   └── flake.nix
└── flake.nix
```

**プロジェクトルートの `flake.nix` にて「テンプレートの名前・コピー元」といった情報を定義します**。

以下は設定例です。

```nix:~/work/nix-template/flake.nix
{
  description = "Nix template";
  outputs =
    { self }:
    {
      templates.basic = {
        path = ./basic;
        description = "Basic project";
      };
      templates.default = self.templates.basic;
    };
}
```

```nix:~/work/nix-template/basic/flake.nix
{
  description = "Basic template";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      supportSystems = with flake-utils.lib.system; [
        x86_64-linux
        aarch64-darwin
      ];
    in
    flake-utils.lib.eachSystem supportSystems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (pkgs.lib.getName pkg) [
            ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
          ];
        };
      }
    );
}
```

```:~/work/nix-template/basic/.envrc
use flake
```

:::message
**フォルダ単位（`./basic/`）でテンプレートとして指定できます**。
**また、`flake.nix` 以外のファイルもフォルダに含めることが可能です**。
:::


# 3. 自作テンプレートを利用する
以下のようにローカルの絶対パスを指定すると、自作テンプレートを利用できます。

- default で定義したテンプレート

```zsh:Zsh
nix flake init -t /Users/ryu/work/nix-template
```

- basic で定義したテンプレート

```zsh:Zsh
nix flake init -t /Users/ryu/work/nix-template#basic
```

----


# 4. 自作テンプレートを公開する
**GitHub の Public レポジトリとして自作テンプレートを管理すれば、以下のように呼び出すこともできます**。

```zsh:Zsh
nix flake init -t "github:ryuryu333/nix-template"
```

https://github.com/ryuryu333/nix-template


# 5. 自作テンプレートの呼び出しを簡易化する
普段使いする場合、以下のような長いコマンドは使い勝手が悪いです。

```zsh:Zsh
nix flake init -t "github:ryuryu333/nix-template"
```

**そこで、Nix の設定を変更して `nix flake init` だけで自作テンプレートを利用できるようにします**。


:::message
**注意**。
本セクションでは標準のテンプレート（`template`）を置き換えます。
:::


#### Home Manager を利用する場合（推奨）

```nix:home.nix
  nix.registry = {
    templates = {
      from = { type = "indirect"; id = "templates"; };
      to = { type = "github"; owner = "ryuryu333"; repo = "nix_template"; };
    };
  };
```

#### コマンド実行で設定する場合

```zsh:Zsh
nix registry add templates github:ryuryu333/nix_template
```

設定を元に戻したい場合は `remove` してください。

```zsh:Zsh
nix registry remove templates
```

#### 動作確認
以下のコマンドで自作テンプレートを利用できるようになったはずです。

```zsh:Zsh
nix flake init
```

----

このセクションではレジストリという仕組みを利用しています。
レジストリについては以下で解説しています。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/tips-05
