---
title: "個別にツールのバージョンを管理する方法"
---

# 1. この章でやること
この章では特定のバージョンのパッケージを利用する方法を解説します。

Nix では様々な方法でバージョンを指定できます。

- Nixpkgs をピン留め
- overrideAttrs でパッケージ定義を上書き
- overlays で Nixpkgs の定義を上書き
- nix-versions を利用
- 有志のバイナリキャッシュを利用（一部のパッケージのみ）

**本章では実用性の高い方法（nix-versions など）から紹介し、その後、基礎的な方法（overrideAttrs など）を解説します**。

:::message
**・各方法の使い分けについて**

**有名なパッケージなら、`有志のバイナリキャッシュを利用` を検討する**。
Python、Go など言語本体や Claude Code などはある。

Nixpkgs に反映されていない最新バージョンが使える、設定が書きやすい、キャッシュが効く（ビルドが早い）といった利点がある。

----

**上記以外のパッケージの場合、`nix-versions を利用`する**。

`Nixpkgs をピン留め`する方法をベースとし、より簡易的かつ柔軟にバージョンを指定できるのでお勧めです。

----

**Nixpkgs 未登録のバージョン、未反映の最新バージョンを使いたいなら `overrideAttrs でパッケージ定義を上書き`**。

----

**Nixpkgs 未登録のバージョンを使い、かつ、複数プロジェクトで設定したいなら `overlays で Nixpkgs の定義を上書き`**。

`flake.nix` の `outputs` として自分用の `overlays` を定義して、他の `flake.nix` から呼び出すと楽です。
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

執筆時点（2026/3/4）では、`1.25.7` がビルドされました。

```bash:Bash
$ nix develop -c go version
go version go1.25.7 linux/amd64
```

以降では、`1.25.7` 以外の Go を利用する方法を紹介していきます。


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
:::

:::message alert
**この方法では、Nixpkgs に登録されたことがあるバージョンのみ利用できます**。

例えば、Go `1.25.6` は Nixpkgs に登録されたことが無いため、[nixhub.io](https://www.nixhub.io/) で検索しても一覧に記載されていません。

![検索結果](/images/1c0373f3570334/tips-03/tips-03-2026-3-4.webp)
:::


# 4. overrideAttrs でパッケージ定義を上書き
先ほどはパッケージ定義の参照元（Nixpkgs）を変更する手法でした。

本セクションでは、パッケージ定義の参照元は変えません。
**Go のビルド定義を参照する際に、バージョン情報などを上書きする**ことで、別バージョンをビルドさせます。

ただし、この方法は 2 回に分けて作業が必要になります。

#### 4.1 ハッシュ値の取得
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
            };
          }
        );
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
当然、`src` から計算したハッシュ値と `hash` の値が異なるのでエラーとなります。

```:エラー抜粋
specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
got:    sha256-WMv3ceRNdt5vVtGeM7d9dFoeSJNAkih15GWFuXXCsFk=
```

**エラーに表示された `got` が `src` から計算されたハッシュ値です**。

#### 4.2 ハッシュ値の指定
特定したハッシュ値を `hash` として利用すると、エラー無く Go がビルドされます。

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
            };
          }
        );
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

:::message alert
**パッケージによって記述方法が変わります**。
`src` の取得に `fetchFromGitHub` を使っている場合は、以下のようになります。

```nix
  src = fetchFromGitHub {
    owner = "astral-sh";
    repo = "uv";
    tag = finalAttrs.version;
    hash = pkgs.lib.fakeHash;;
  };
```

また、パッケージのビルド方法によっては、追加で作業が必要な場合もあります（後述）。

----

パッケージの定義を直接読んでコードに記述をしていく必要があり、かつ、ハッシュ値を取得する手間もあるため、この方法は使うのが難しいかもしれません。

しかし、ビルド定義を直接いじくれるので、柔軟性はあるかと思います。
:::

:::details Rust 製パッケージの場合
Rust 製の場合、`rustPlatform.buildRustPackage` という関数でビルドを行います。

この関数では、`cargoHash` が必要となります。

`cargoHash` は `src` のように単純な上書きはできない仕様であるため、`cargoDeps = pkgs.rustPlatform.fetchCargoVendor` を使います。

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

`src.hash` のハッシュ値が特定できます。

```bash:Bash
$ nix develop -c uv --version
error: hash mismatch in fixed-output derivation '/nix/store/g89wzzyhlnp6iafwjl9mbahp1sdrwfkc-source.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-vJvF8ioEtiriWh120WhMxkYSody04PuXA6EISjWWvYA=
```

次の実行で、`hash` も特定できます。

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

**注意**。ビルドにかなり時間がかかります。
12 分ほどかかりました。

```bash:Bash
$ nix develop -c uv --version
warning: Git tree '/home/ryu/dev/test' is dirty
uv 0.6.13
```

:::


# 5. overlays で Nixpkgs の定義を上書き
前セクションの overrideAttrs に似た手法となります。

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
          overlays = [ myOverlay ];
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
**`myOverlay` の中で書いているコードは先ほどの overrideAttrs と同じ内容です**。

ハッシュ値の調べ方などの方法・諸注意は overrideAttrs と同様です。
:::


# 6. nix-versions を利用
今までの方法は Nix の通常機能を駆使した方法でした。

**これ以降のセクションは公式外のツールを用いた手段です**。
**本章を読んだ時期によっては、メンテナンスが途絶えている場合も想定されるので注意してください**。

:::details サービスが途絶えた例
過去に、Nixpkgs のリビジョンとパッケージのバージョン一覧を調べるサイトとして、[lazamar.co.uk/nix-versions](https://lazamar.co.uk/nix-versions/) がありました。

執筆時点（2026/3/4）だと、更新が止まっており、2025/6 頃の情報までしかありません。
:::

----

[nix-versions](https://github.com/vic/nix-versions) はパッケージの各バージョン対応した Nixpkgs のリビジョンを調べるツールです。

情報源は前セクションでも紹介した [nixhub.io](https://www.nixhub.io/) などです。

```bash:Bash
$ nix run github:vic/nix-versions -- go
Name  Version    NixInstallable           VerBackend  
go    1.25rc2    nixpkgs/648f701#go_1_25  nixhub      
# 中略...
go    1.25.5     nixpkgs/a1bab9e#go       nixhub      
go    1.25.7     nixpkgs/80d901e#go       nixhub      
go    1.26.0     nixpkgs/80d901e#go_1_26  nixhub  
```

nix-versions は `flake.nix` に組み込むと簡単に特定バージョンを指定できます。

```diff nix:flake.nix
{
  description = "Basic template";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
+   nix-versions.url = "https://nix-versions.oeiuwq.com/flake.zip/go@1.25.5";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
+     nix-versions
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
+           nix-versions.packages.${system}.go
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

バージョンの指定方法は複数あります。

```:指定例
nix-versions.url = "https://nix-versions.oeiuwq.com/flake.zip/go@1.25.5";
-> go version go1.25.5 linux/amd64

nix-versions.url = "https://nix-versions.oeiuwq.com/flake.zip/go@~1.25";
-> go version go1.25.7 linux/amd64

nix-versions.url = "https://nix-versions.oeiuwq.com/flake.zip/go@1.25.x";
-> go version go1.25.7 linux/amd64

nix-versions.url = "https://nix-versions.oeiuwq.com/flake.zip/go@1.x";
-> go version go1.26.0 linux/amd64

nix-versions.url = "https://nix-versions.oeiuwq.com/flake.zip/go@latest";
-> go version go1.26.0 linux/amd64
```

:::message
内部処理は前半のセクションで紹介した Nixpkgs をピン留めする方法と同じです。
そのため、**Nixpkgs に登録されたことがあるバージョンのみ利用できます**。

```bash:Bash
$ nix run github:vic/nix-versions -- go@~1.25.4
Name  Version  NixInstallable      VerBackend  
go    1.25.4   nixpkgs/ee09932#go  nixhub      
go    1.25.5   nixpkgs/a1bab9e#go  nixhub      
go    1.25.7   nixpkgs/80d901e#go  nixhub 
```

例えば、Nixpkgs に登録されたことがない `Go 1.25.6` を指定するとエラーとなります。

```:具体例
nix-versions.url = "https://nix-versions.oeiuwq.com/flake.zip/go@1.25.6";
-> error: unable to download 'https://nix-versions.oeiuwq.com/flake.zip/go@1.25.6': HTTP error 500
```

:::


# 7. 有志のバイナリキャッシュを利用（一部のパッケージのみ）
**有名なパッケージの場合、有志がバージョンごとにバイナリキャッシュを揃えている可能性があります**。
Nixpkgs に登録されなかった過去バージョン、Nixpkgs に未反映の最新バージョンを利用できることが多いです。

:::message
更新頻度が高いパッケージや過去バージョンを厳密に指定したい際、有用です。
:::

例えば、以下のようなレポジトリが公開されています。

- [purpleclay/go-overlay](https://github.com/purpleclay/go-overlay)
- [cachix/nixpkgs-python](https://github.com/cachix/nixpkgs-python)
- [oxalica/rust-overlay](https://github.com/oxalica/rust-overlay)
- [numtide/llm-agents](https://github.com/numtide/llm-agents.nix)

具体的な利用方法は各レポジトリのドキュメントをご確認ください。
これまで紹介してきた方法（overlays など）と似た記述方法かと思います。

:::message
これらのレポジトリはネット検索して地道に見つける必要があります。

言語に関しては、devenv というツールのソースコードを読むと探しやすいです。

例えば、Python について調べる場合、[リファレンスの Python 設定一覧ページ](https://devenv.sh/languages/python/#languagespythonversion)を開き、バージョンを指定する設定項目を探します。

![Python の例](/images/1c0373f3570334/tips-03/tips-03-2026-3-6.webp)

記述されている[ソースコード（`Declared by:...`）](https://github.com/cachix/devenv/blob/main/src/modules/languages/python/default.nix)を開きます。

nix ファイル（`default.nix` など）から、`github` や `cachix` と書かれている箇所が大抵はあるはずです。

```nix:src/modules/languages/python/default.nix
  nixpkgs-python = config.lib.getInput {
    name = "nixpkgs-python";
    url = "github:cachix/nixpkgs-python";
    attribute = "languages.python.version";
    follows = [ "nixpkgs" ];
  };
```

Python の場合、devenv は `cachix/nixpkgs-python` という GitHub リポジトリを利用していると分かります。
:::
