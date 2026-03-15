---
title: "テンプレートの活用"
---

# 1. この章でやること
この章では `flake.nix` のテンプレートを準備、活用する方法を解説します。


:::message
`flake.nix` に記述する内容の多くは使いまわせます。
そのため、テンプレートを用意しておくと `package = []` の中身を書き換えるだけで環境構築が素早く終わります。
:::


# 2. 標準のテンプレートを利用する
特別な準備をせずとも Nix では `flake.nix` のテンプレートを利用できます。

```zsh:Zsh
nix flake init
```

```nix:生成される flake.nix
{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

    packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

  };
}
```

特定の言語に特化したテンプレートも用意されています。

```zsh:Zsh
nix flake init -t templates#python
```

```nix:生成される flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.poetry2nix.url = "github:nix-community/poetry2nix";

  outputs = { self, nixpkgs, poetry2nix }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (system: let
        inherit (poetry2nix.lib.mkPoetry2Nix { pkgs = pkgs.${system}; }) mkPoetryApplication;
      in {
        default = mkPoetryApplication { projectDir = self; };
      });

      devShells = forAllSystems (system: let
        inherit (poetry2nix.lib.mkPoetry2Nix { pkgs = pkgs.${system}; }) mkPoetryEnv;
      in {
        default = pkgs.${system}.mkShellNoCC {
          packages = with pkgs.${system}; [
            (mkPoetryEnv { projectDir = self; })
            poetry
          ];
        };
      });
    };
}
```

:::message
テンプレートによっては `flake.nix` 以外のファイルも生成されます。

上記 Python テンプレートの場合、Poetry 関連のファイルも生成されます。

```zsh:Zsh
> tree
.
├── flake.nix
├── poetry.lock
├── pyproject.toml
├── README.md
└── sample_package
    ├── __init__.py
    └── __main__.py
```

:::

テンプレートは [NixOS/templates](https://github.com/NixOS/templates) に定義されています。
以下のコマンドで一覧を確認できます。

```zsh:Zsh
nix flake show templates
```


# 3. 他者が公開しているテンプレートを利用する
`nix flake init` コマンドでは GitHub レポジトリを指定して、外部のテンプレートを読み込む機能があります。

[the-nix-way/dev-templates](https://github.com/the-nix-way/dev-templates) から Python テンプレートを以下のように利用できます。

```zsh:Zsh
nix flake init -t "https://flakehub.com/f/the-nix-way/dev-templates/*#python"
```

<!-- cspell:disable -->

```nix:生成される flake.nix
{
  description = "A Nix-flake-based Python development environment";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # unstable Nixpkgs

  outputs =
    { self, ... }@inputs:

    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import inputs.nixpkgs { inherit system; };
          }
        );

      /*
        Change this value ({major}.{min}) to
        update the Python virtual-environment
        version. When you do this, make sure
        to delete the `.venv` directory to
        have the hook rebuild it for the new
        version, since it won't overwrite an
        existing one. After this, reload the
        development shell to rebuild it.
        You'll see a warning asking you to
        do this when version mismatches are
        present. For safety, removal should
        be a manual step, even if trivial.
      */
      version = "3.13";
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs }:
        let
          concatMajorMinor =
            v:
            pkgs.lib.pipe v [
              pkgs.lib.versions.splitVersion
              (pkgs.lib.sublist 0 2)
              pkgs.lib.concatStrings
            ];

          python = pkgs."python${concatMajorMinor version}";
        in
        {
          default = pkgs.mkShellNoCC {
            venvDir = ".venv";

            postShellHook = ''
              venvVersionWarn() {
                local venvVersion
                venvVersion="$("$venvDir/bin/python" -c 'import platform; print(platform.python_version())')"

                [[ "$venvVersion" == "${python.version}" ]] && return

                cat <<EOF
              Warning: Python version mismatch: [$venvVersion (venv)] != [${python.version}]
                       Delete '$venvDir' and reload to rebuild for version ${python.version}
              EOF
              }

              venvVersionWarn
            '';

            packages = with python.pkgs; [
              venvShellHook
              pip

              # Add whatever else you'd like here.
              # pkgs.basedpyright

              # pkgs.black
              # or
              # python.pkgs.black

              # pkgs.ruff
              # or
              # python.pkgs.ruff
            ];
          };
        }
      );
    };
}
```

<!-- cspell:enable -->

```:その他の生成されたファイル
.
├── .envrc
├── .gitignore
└── flake.nix
```


# 4. テンプレートを自作する
ローカルに以下のようなフォルダを作成します。

```:フォルダ構成
~/work/nix_template/
├── basic
│   ├── .envrc
│   └── flake.nix
└── flake.nix
```

プロジェクトルートの `flake.nix` にて「テンプレートの名前・コピー元」といった情報を定義します。

テンプレート保存先（`./basic/`）にあるファイルが `nix flake init -t ...` コマンドでコピーされます。

以下は設定例です。

```nix:~/work/nix_template/flake.nix
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

```nix:~/work/nix_template/basic/flake.nix
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

```:~/work/nix_template/basic/.envrc
use flake
```

# 5. 自作テンプレートを利用する
以下のようにローカルの絶対パスを指定すると、自作テンプレートを利用できます。

```zsh:Zsh
nix flake init -t /Users/ryu/work/nix_template
```

```zsh:Zsh
nix flake init -t /Users/ryu/work/nix_template#basic
```

GitHub の Public レポジトリとして自作テンプレートを管理すれば、以下のように呼び出すこともできます。

```zsh:Zsh
nix flake init -t "github:ryuryu333/nix_template"
```

https://github.com/ryuryu333/nix_template


# 6. 自作テンプレートの呼び出しを簡易化する
普段使いする場合、以下のような長いコマンドは使い勝手が悪いです。

```zsh:Zsh
nix flake init -t "github:ryuryu333/nix_template"
```

そこで、Nix の設定を変更して `nix flake init` だけで自作テンプレートを利用できるようにします。


:::message
**注意**。
本セクションでは標準のテンプレート（`template`）を置き換えます。
標準のテンプレートを呼び出すが面倒になります。
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

----

以下のコマンドで自作テンプレートを利用できるようになったはずです。

```zsh:Zsh
nix flake init
```


::::::details レジストリについて
Nix コマンドを実行する際、GitHub リポジトリを参照する場合はレポジトリ名などを入力する必要があります。

```zsh:Zsh
> nix run github:NixOS/nixpkgs/nixpkgs-unstable#hello
Hello, world!
```

しかし、毎回 `github:NixOS/nixpkgs/nixpkgs-unstable` と打ち込むのは大変です。
[Nix のレジストリ機能](https://nix.dev/manual/nix/2.18/command-ref/new-cli/nix3-registry)を利用すると、`nixpkgs` のように任意の名前を付けることができます。


:::message
デフォルトで多くのレポジトリが登録されており、`nixpkgs` も登録済みです。

```zsh:Zsh
> nix registry list | grep nixpkgs
global flake:nixpkgs github:NixOS/nixpkgs/nixpkgs-unstable
```

:::

レジストリにより、短い記述で Nix コマンドが利用できます。

```zsh:Zsh
> nix run github:NixOS/nixpkgs/nixpkgs-unstable#hello
Hello, world!

> nix run nixpkgs#hello
Hello, world!

> nix run nixpkgs#hello --no-use-registries
error: 'flake:nixpkgs' is an indirect flake reference, but registry lookups are not allowed
```

----

`nix flake init` で参照されるテンプレートも `templates` としてレジストリに登録されています。

```zsh:Zsh
> nix registry list | grep templates
global flake:templates github:NixOS/templates
```

先ほどの設定では、`templates` として自作テンプレートを置いているレポジトリを指定しました。

```zsh:Zsh
> nix registry list | grep templates
user   flake:templates github:ryuryu333/nix_template
global flake:templates github:NixOS/templates
```

:::message
レジストリ設定は `/etc/nix/registry.json` と `~/.config/nix/registry.json` に保存されています。

自作 `templates` はユーザー環境の設定に登録しました。

```zsh:Zsh
> cat ~/.config/nix/registry.json
{
  "flakes": [
    {
      "exact": true,
      "from": {
        "id": "templates",
        "type": "indirect"
      },
      "to": {
        "owner": "ryuryu333",
        "repo": "nix_template",
        "type": "github"
      }
    }
  ],
  "version": 2
}
```

:::

::::::
