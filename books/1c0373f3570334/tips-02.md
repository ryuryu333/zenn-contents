---
title: "unfree license エラーへの対処法"
---

# 1. この章でやること
この章では unfree license なパッケージを Nix で利用する方法を解説します。


# 2. unfree license 利用時のエラー
**デフォルト設定の場合、Nix では商用ライセンスで公開・配布が制限されているパッケージを利用できません**。

例えば、[Terraform](https://github.com/hashicorp/terraform) は [BSL 1.1](https://spdx.org/licenses/BUSL-1.1.html) であり、厳密には OSS ではありません（2026/3 執筆時点）。
そのため、以下のように Terraform を Nix で利用すると、エラーが発生します。

<!-- cspell:disable -->

```zsh:Zsh
> nix run nixpkgs#terraform
error: Refusing to evaluate package 'terraform-1.14.6' in /nix/store/s9ynh85lpfxg1b0p6a452lx9ra9c3xdy-source/pkgs/applications/networking/cluster/terraform/default.nix:85 because it has an unfree license (‘bsl11’)
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
             "terraform"
           ];
         }

       c) For `nix-env`, `nix-build`, `nix-shell` or any other Nix command you can add
         { allowUnfree = true; }
       to ~/.config/nixpkgs/config.nix.
```

<!-- cspell:enable -->

# 3. 対処法
対処方針として、unfree license を全て許可する（`allowUnfree`）か一部だけ許可する（`allowUnfreePredicate`）かを選ぶ必要があります。

なお、許可設定はユーザー環境全体、プロジェクト単位どちらでも指定できます。

:::message
**個人的には、「一部だけを許可する」方が宣言的なので好みです**。

ユーザー環境へ入れるパッケージに unfree があれば、ユーザー環境の許可設定に追加しています。
プロジェクト単位でも同様です。

パッケージを使う場所の近くで unfree の許可を指定すると管理が楽になると思います。
:::


## 3.1 Home Manager や nix-darwin の場合

```nix:home.nix / configuration.nix
  # 全てを許可
  nixpkgs.config.allowUnfree = true;

  # 一部だけを許可
  nixpkgs.config.allowUnfreePredicate = (
    pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "terraform"
    ]
  );
```


## 3.2 Flakes devShell の場合

```nix:flake.nix
    flake-utils.lib.eachSystem supportSystems (
      system:
      let
        # 全てを許可
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # 一部だけを許可
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (pkgs.lib.getName pkg) [
            ];
        };
      in
      {
        #... 
      }
```

# 4. 参考資料

https://wiki.nixos.org/wiki/Unfree_software

