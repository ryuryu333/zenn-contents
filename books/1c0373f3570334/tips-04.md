---
title: "overrideAttrs などでバージョンを変更する方法"
---

# 1. この章でやること
この章では、Nix 言語の機能を利用して、特定のバージョンのパッケージを利用する方法を解説します。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/tips-04

上記の章では、サードパーティ製ツールで手軽にパッケージのバージョンを指定する方法を紹介しました。

**本章では、`overrideAttrs` や `overlays` といった Nix 言語の関数の使い方、Nixpkgs のピン留めによるバージョン管理といった方法を解説します**。
これらを知ることで、サードパーティ製ツールの動作原理や利用方法が理解しやすくなると思います。

また、サードパーティ製ツールでは実現できない事柄（マイナーなパッケージで Nixpkgs 未反映のバージョンを使う、など）は、本章の方法で実装することになります。


:::message
Nixpkgs のソースコードを見る場面も出てくるため、Nix に慣れてきた後にお読みください。
:::


# 2. 前提条件
Flakes devShell にて [Go](https://go.dev/) を利用すると仮定します。

```nix:flake.nix
{
  description = "Pinned Go version";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils
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
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            go
          ];
        };
      }
    );
}
```

執筆時点（2026/3/8）では、`1.25.7` が構築されました。

```bash:Bash
$ nix develop -c go version
go version go1.25.7 linux/amd64
```


# 3. Nixpkgs をピン留め
`flake.nix` では Nixpkgs のブランチを `inputs` に指定し、`nix flake update` した時点で最新リビジョンが `flake/lock` にて固定されます。

```nix:flake.nix
inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
```

`inputs` ではブランチではなく、リビジョンも指定できます。

そのため、以下のように特定時期の Nixpkgs を定義し、Go を参照することで、別バージョンの Go をビルドできます。

```diff nix:flake.nix
{
  description = "Pinned Go version";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
+   goPinned.url = "github:nixos/nixpkgs/a1bab9e494f5f4939442a57a58d0449a109593fe";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
+     goPinned,
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
        pkgs = nixpkgs.legacyPackages.${system};
+       myGo = goPinned.legacyPackages.${system}.go;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
+           myGo
          ];
        };
      }
    );
}
```

```bash:Bash
$ nix develop -c go version
go version go1.25.5 linux/amd64
```

:::message
**Nixpkgs のリビジョンとパッケージのバージョンについて**。

[nixhub.io](https://www.nixhub.io/) にてパッケージ名で検索すると、どのバージョンがどのリビジョンに対応しているか調べられます。

また、[nix-versions](https://github.com/vic/nix-versions) を使うと CLI で簡単に検索できます。

```bash:Bash
$ nix run github:vic/nix-versions -- go
Name  Version    NixInstallable           VerBackend  
go    1.25rc2    nixpkgs/648f701#go_1_25  nixhub      
# 中略...
go    1.25.5     nixpkgs/a1bab9e#go       nixhub      
go    1.25.7     nixpkgs/80d901e#go       nixhub      
go    1.26.0     nixpkgs/80d901e#go_1_26  nixhub  
```

`flake.nix` では短縮形のハッシュ値も指定できるので、以下のように指定できます。

```nix:flake.nix
# 1.25.5
goPinned.url = "github:nixos/nixpkgs/a1bab9e";
```


:::

:::message alert
**この方法では、Nixpkgs に登録されたことがあるバージョンのみ利用できます**。

例えば、Go `1.25.6` は Nixpkgs に登録されたことが無いため、[nixhub.io](https://www.nixhub.io/) で検索しても一覧に記載されていません。

![検索結果](/images/1c0373f3570334/tips-03/tips-03-2026-3-4.webp)
:::


# 4. overrideAttrs でパッケージ定義を上書き
先ほどはパッケージ定義の参照元（Nixpkgs）を変更する手法でした。

本セクションでは、パッケージ定義の参照元は変えません。
**Go のビルド定義を参照する際に、利用するソースを上書きする**ことで、別バージョンをビルドさせます。

この方法は Nixpkgs に登録されたことがないバージョンであっても、Nix でビルド可能にできることが利点です。
ただし、2 回に分けて作業が必要になります。


## 4.1 ハッシュ値の取得
以下のように、[overrideAttrs](https://nixos.org/manual/nixpkgs/stable/#sec-pkg-overrideAttrs) で `version` と `src` を上書きします。

```diff nix:flake.nix
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
        pkgs = nixpkgs.legacyPackages.${system};
+       myGo = pkgs.go.overrideAttrs (
+         finalAttrs: previousAttrs: {
+           version = "1.25.6";
+           src = pkgs.fetchurl {
+             url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
+             hash = pkgs.lib.fakeHash;
+           };
+         }
+       );
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            myGo
          ];
        };
      }
    );
}
```

この状態でビルドを始めると、エラーになります。

```bash:Bash
$ nix develop -c go version
error: hash mismatch in fixed-output derivation '/nix/store/p85zdrxq4lxx2qx6ahs7xwkzd7b9pran-go1.25.6.src.tar.gz.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-WMv3ceRNdt5vVtGeM7d9dFoeSJNAkih15GWFuXXCsFk=
# ...
```

**Nix は `src` としてビルドに使うソースコードを取得する際、ソースコードからハッシュ値を計算し、ビルド定義と差異が無いかをチェックします**。

そのため、`src` を上書きする際、`src` に対応したハッシュ値を調べる必要があります。

上記コードではダミーハッシュ値を定義しました（`hash = pkgs.lib.fakeHash`）。
当然、`src` から計算したハッシュ値と `fakeHash` の値は異なるのでエラーとなります。

```:エラー抜粋
specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
got:    sha256-WMv3ceRNdt5vVtGeM7d9dFoeSJNAkih15GWFuXXCsFk=
```

**エラーに表示された `got` が `src` から計算されたハッシュ値です**。


## 4.2 ハッシュ値の指定
`got` したハッシュ値を `hash` として利用すると、エラー無く Go がビルドされます。

```diff nix:flake.nix
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
        pkgs = nixpkgs.legacyPackages.${system};
+       myGo = pkgs.go.overrideAttrs (
+         finalAttrs: previousAttrs: {
+           version = "1.25.6";
+           src = pkgs.fetchurl {
+             url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
+             hash = "sha256-WMv3ceRNdt5vVtGeM7d9dFoeSJNAkih15GWFuXXCsFk=";
+           };
+         }
+       );
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            myGo
          ];
        };
      }
    );
}
```

```bash:Bash
$ nix develop -c go version
go version go1.25.6 linux/amd64
```

:::message
**Nixpkgs で管理されているバイナリキャッシュが利用できないため、ローカルでビルドされます**。
マシンスペックによりますが、1 分以上かかるかもしれません。
:::


## 4.3 設定記述方法の調べ方
**パッケージによって　`overrideAttrs`　の記述方法が変わります**。

まず、対象のパッケージのビルド定義を調べる必要があります。
Go の場合、[nixpkgs/pkgs/development/compilers/go/1.25.nix](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/compilers/go/1.25.nix) に記載されています。

:::message
[search.nixos.org](https://search.nixos.org/packages) でパッケージを検索し、`📦 Source` という場所をクリックすると、Nixpkgs のソースコードに飛べます。
:::

src などで単語検索すると、以下のコードが見つかります。

```nix
  src = fetchurl {
    url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
    hash = "sha256-F48oMoICdLQ+F30y8Go+uwEp5CfdIKXkyI3ywXY88Qo=";
  };
```

これが、Go をビルドする際のソースコードを定義している箇所です。
この `src` を上書きすれば異なるバージョンをビルドできます。

>実際、パッケージのビルドレシピを更新する場合、この `src` の内容を更新します。

この `src` 取得の部分はパッケージによって異なります。
例えば、`fetchFromGitHub` を使っている場合は以下のように記述されています。

```nix
  src = fetchFromGitHub {
    owner = "astral-sh";
    repo = "uv";
    tag = finalAttrs.version;
    hash = "sha256-HsMZzn7D2C19Uu9xmz4NRaK+cGcoiyJYaAq1Z9f5nwY=";
  };
```

`overrideAttrs` で `src` を上書きする場合、`src` 以下のアトリビュートをそれぞれ指定する必要があります。

```nix:flake.nix
  myGo = pkgs.go.overrideAttrs (
    finalAttrs: previousAttrs: {
      version = "1.25.6";
      src = pkgs.fetchurl {
        url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
        hash = pkgs.lib.fakeHash;
      };
    }
  );

  myUv = pkgs.uv.overrideAttrs (
    finalAttrs: previousAttrs: {
      version = "0.6.13";
      src = fetchFromGitHub {
        owner = "astral-sh";
        repo = "uv";
        tag = finalAttrs.version;
        hash = pkgs.lib.fakeHash;
      };
    }
  );
```


## 4.4 特殊な記述が必要なパッケージ
**パッケージのビルド方法によっては、追加で作業が必要な場合もあります**。

### 4.4.1 Rust 製パッケージ
Rust 製パッケージは `rustPlatform.buildRustPackage` という Nix の関数でビルドを行います。

この関数では、`cargoHash` が必要となります。
**`cargoHash` は `src` のように単純な上書きはできない仕様**であるため、`cargoDeps = pkgs.rustPlatform.fetchCargoVendor` を使います。

----

まず、`src.hash` と `hash` どちらもダミーハッシュを指定します。

```nix
        myUv = pkgs.uv.overrideAttrs (
          finalAttrs: previousAttrs: {
            version = "0.6.13";
            src = pkgs.fetchFromGitHub {
              owner = "astral-sh";
              repo = "uv";
              rev = finalAttrs.version;
              hash = pkgs.lib.fakeHash;
            };
            cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
              inherit (finalAttrs) src;
              hash = pkgs.lib.fakeHash;
            };
          }
        );
```

一度目の実行では `src` にて fetch するソースコードのハッシュ値が検証される段階でエラーになります。

```bash:Bash
$ nix develop -c uv --version
error: hash mismatch in fixed-output derivation '/nix/store/g89wzzyhlnp6iafwjl9mbahp1sdrwfkc-source.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-vJvF8ioEtiriWh120WhMxkYSody04PuXA6EISjWWvYA=
```

これで `src.hash` が特定できるので、反映させます。

二度目の実行では `cargoDeps` にてソースコードのハッシュ値が検証される段階でエラーになります。

```nix
        myUv = pkgs.uv.overrideAttrs (
          finalAttrs: previousAttrs: {
            version = "0.6.13";
            src = pkgs.fetchFromGitHub {
              owner = "astral-sh";
              repo = "uv";
              rev = finalAttrs.version;
              hash = hash = "sha256-vJvF8ioEtiriWh120WhMxkYSody04PuXA6EISjWWvYA=";
            };
            cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
              inherit (finalAttrs) src;
              hash = pkgs.lib.fakeHash;
            };
          }
        );
```

```bash:Bash
$ nix develop -c uv --version
error: hash mismatch in fixed-output derivation '/nix/store/g89wzzyhlnp6iafwjl9mbahp1sdrwfkc-source.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-pwbqYe2zdQJQGoqrIwryBHmnS8spPgQ0qdpmxdT+9sk=
```

これで `cargoDeps.hash` が特定できるので、反映させます。

全てのハッシュ値を特定できたので、ビルドが出来ます。

```nix
        myUv = pkgs.uv.overrideAttrs (
          finalAttrs: previousAttrs: {
            version = "0.6.13";
            src = pkgs.fetchFromGitHub {
              owner = "astral-sh";
              repo = "uv";
              rev = finalAttrs.version;
              hash = "sha256-vJvF8ioEtiriWh120WhMxkYSody04PuXA6EISjWWvYA=";
            };
            cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
              inherit (finalAttrs) src;
              hash = "sha256-pwbqYe2zdQJQGoqrIwryBHmnS8spPgQ0qdpmxdT+9sk=";
            };
          }
        );
```

```bash:Bash
$ nix develop -c uv --version
warning: Git tree '/home/ryu/dev/test' is dirty
uv 0.6.13
```

:::message
**注意**。ビルドにかなり時間がかかります。
筆者環境では 12 分ほどかかりました。
:::


# 5. overlays で Nixpkgs の定義を上書き
前セクションの `overrideAttrs` に似た手法となります。

先ほどは、Go のビルド定義を参照する際に、バージョン情報などを上書きしました。

```nix
# pkgs を nixpkgs から定義
pkgs = nixpkgs.legacyPackages.${system};

# Go を取得する際に上書き
myGo = pkgs.go.overrideAttrs ...;
```

**これでは、別のパッケージが依存として Go を利用する場合、Go のバージョンは上書き前（通常通り）となってしまいます**。

```nix
# hoge の依存に Go があった場合、pkgs.go が参照される
# -> myGo は参照されない
myHoge = pkgs.hoge;
```

環境の設計意図によりますが、もしも Go のバージョンを依存含め特定バージョンに固定したい場合、本セクションの方法を利用します。

----

Nixpkgs からパッケージ定義の情報を取得する際、[overlays](https://nixos.org/manual/nixpkgs/stable/#sec-overlays-definition) で変更を加えることが出来ます。

```nix
# 通常
pkgs = import nixpkgs {
  inherit system;
};

# myOverlays に記載された変更が反映される
pkgs = import nixpkgs {
  inherit system;
  overlays = [ myOverlay ];
};

# myOverlay で定義が変更された Go が取得できる
myGo = pkgs.go;
```

----

以下のように overlays を利用します。

```diff nix:flake.nix
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
+     myOverlay = final: prev: {
+       go = prev.go.overrideAttrs (
+         finalAttrs: previousAttrs: {
+           version = "1.25.6";
+           src = prev.fetchurl {
+             url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
+             hash = "sha256-WMv3ceRNdt5vVtGeM7d9dFoeSJNAkih15GWFuXXCsFk=";
+           };
+         }
+       );
+     };
    in
    flake-utils.lib.eachSystem supportSystems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
+         overlays = [ myOverlay ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            go
          ];
        };
      }
    );
}
```

```bash:Bash
$ nix develop -c go version
go version go1.25.6 linux/amd64
```


:::message
**`myOverlay` の中で書いているコードは先ほどの `overrideAttrs` と同じ内容です**。

ハッシュ値の調べ方などの方法・諸注意は `overrideAttrs` と同様です。
:::


:::message
**`flake.nix` では `outputs` として `overlays` を定義できます**。

```nix
overlays."<name>" = final: prev: { };
```

`outputs` に定義しておくと、外部の `flake.nix` から `inputs` 経由で `overlays` を利用できます。
複数プロジェクトで共通の `overlays` を使いまわせるので便利です。

>[purpleclay/go-overlay](https://github.com/purpleclay/go-overlay) などが活用例と言えます。

:::

