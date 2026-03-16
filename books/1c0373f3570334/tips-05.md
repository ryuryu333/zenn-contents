---
title: "レジストリの仕組みと活用例"
---

# 1. この章でやること
この章では、Nix のレジストリについて解説します。


# 2. レジストリとは
Nix コマンドを実行する際、GitHub リポジトリを参照する場合はレポジトリ名などを入力する必要があります。

```zsh:Zsh
> nix run github:NixOS/nixpkgs/nixpkgs-unstable#hello
Hello, world!
```

しかし、毎回 `github:NixOS/nixpkgs/nixpkgs-unstable` と打ち込むのは大変です。
**[Nix のレジストリ機能](https://nix.dev/manual/nix/2.18/command-ref/new-cli/nix3-registry)を利用すると、`nixpkgs` のように任意の名前を付けることができます**。


:::message
**デフォルトで多くのレポジトリが登録されており、`nixpkgs` も登録済みです**。

```zsh:Zsh
> nix registry list | grep nixpkgs
global flake:nixpkgs github:NixOS/nixpkgs/nixpkgs-unstable
```

:::


# 3. 活用例
## 3.1 Nixpkgs
レジストリにより、短い記述で Nixpkgs のパッケージを利用できます。

```zsh:Zsh
> nix run nixpkgs#hello
Hello, world!

> nix run github:NixOS/nixpkgs/nixpkgs-unstable#hello
Hello, world!

> nix run nixpkgs#hello --no-use-registries
error: 'flake:nixpkgs' is an indirect flake reference, but registry lookups are not allowed
```

## 3.2 Home Manager
Home Manager をインストールした際、以下のコマンドを利用したかと思います。

```zsh:Zsh
nix run home-manager/master -- switch --flake .
```

**これは、レジストリとして登録されている `home-manager` の `master` ブランチを指定してます**。

```zsh:Zsh
> nix registry list | grep home
global flake:home-manager github:nix-community/home-manager
```

つまり、書き下すと以下のようになります。

```zsh
nix run github:nix-community/home-manager/master -- switch --flake .
```

:::message
[nix-community/home-manager](https://github.com/nix-community/home-manager) にはルートに `flake.nix` があります。

`nix run` では `apps`、無ければ `packages` が参照されます。
また、`nix run` 単独なので暗黙的に `nix run #default` だと解釈されます。

Home Manager のレポジトリでは、`apps` は未定義、`packages.default` に `hmPkg`（= `pkgs.callPackage ./home-manager { path = "${self}"; };`）が定義されています。

**そのため、下記コマンドはローカルに Home Manager が無い状態で `home-manager` コマンドを叩く操作だと分かります**。

```zsh:Zsh
nix run home-manager/master -- switch --flake .
```

```zsh:Zsh
home-manager switch --flake .
```

:::


## 3.3 自作テンプレートの呼び出し簡易化
**既存のレジストリを上書きすることで、`nix` コマンドの一部を自分好みに改変できます**。

こちらの記事では、`template` レジストリを自分の GitHub レポジトリに上書きすることで、`nix flake init` コマンドの結果を変えています。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/dev-07

```zsh:Zsh
# As-Is
nix flake init -t "github:ryuryu333/nix-template"

# To-Be
nix flake init
```


# 4. レジストリの追加
既存の `templates` レジストリを自前の GitHub レポジトリに変更する例を解説します。

前提として、通常 `templates` は以下のように登録されています。

```zsh:Zsh
> nix registry list | grep templates
global flake:templates github:NixOS/templates
```

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


# 5. 追加されたレジストリの確認
以下のようになります。

```zsh:Zsh
> nix registry list | grep templates
user   flake:templates github:ryuryu333/nix_template
global flake:templates github:NixOS/templates
```

:::message
**レジストリ設定は `/etc/nix/registry.json` と `~/.config/nix/registry.json` に保存されています**。

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


:::message
変更意図にもよると思いますが、global（`/etc/nix/registry.json`）は変更せずに、user（`~/.config/nix/registry.json`）の追加する方が安全だと思います。
:::
