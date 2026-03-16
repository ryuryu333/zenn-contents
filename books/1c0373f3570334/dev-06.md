---
title: "テンプレートの活用"
---

# 1. この章でやること
この章では `flake.nix` のテンプレートを活用する方法を解説します。


:::message
**`flake.nix` に記述する内容の多くは使いまわせます**。
**そのため、テンプレートを用意しておくと `package = []` の中身を書き換えるだけで環境構築が素早く終わります**。
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

例えば、[the-nix-way/dev-templates](https://github.com/the-nix-way/dev-templates) から Python テンプレートを以下のように利用できます。

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

