---
title: "5.2 個別にパッケージのバージョンを管理する方法"
---

# 1. この章でやること
この章では特定のバージョンのパッケージを利用する方法を解説します。


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

[2026/3/5 に Go `1.25.8` がリリース](https://go.dev/doc/devel/release)されています。
**この最新バージョンを利用したいと仮定して方法を解説します**。

**また、`1.25.6` 等の古いバージョンを使いたい場合も併せて紹介していきます**。


# 3. Nixpkgs 未反映の最新バージョンを利用したい場合
## 3.1 知名度の高いパッケージ限定の方法
本セクションは言語ランタイム（Python・Go など）や AI ツール（Claude Code など）限定の方法です。

上記のようなパッケージは利用者が多く、かつ、特定バージョンの利用、最新バージョンの素早い反映へのニーズが高いため、**有志がバイナリキャッシュを管理しているレポジトリ**が存在しがちです。

**これらレポジトリは Nixpkgs とは別物ですが、Nix の仕組みを用いてパッケージを利用可能にしてくれているため、Home Manager や `flake.nix` で利用可能です**。


### 3.1.1 Go 最新バージョンの指定
Go 言語の場合、[purpleclay/go-overlay](https://github.com/purpleclay/go-overlay) が有用です。

以下のように記述すると、Nixpkgs 未反映の最新バージョン `1.25.8` が利用できます。

```diff nix:flake.nix
{
  description = "Basic template";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
+   go-overlay.url = "github:purpleclay/go-overlay";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
+     go-overlay
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
+       pkgs = import nixpkgs {
+         inherit system;
+         overlays = [ go-overlay.overlays.default ];
+       };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
+           go-bin.versions."1.25.8"
          ];
        };
      }
    );
}
```

```bash:Bash
$ nix develop -c go version
go version go1.25.8 linux/amd64
```


### 3.1.2 Go 以外の有志レポジトリの例
具体的な利用方法は各レポジトリのドキュメントをご確認ください。

- [cachix/nixpkgs-python](https://github.com/cachix/nixpkgs-python)
- [oxalica/rust-overlay](https://github.com/oxalica/rust-overlay)
- [numtide/llm-agents](https://github.com/numtide/llm-agents.nix)


### 3.1.3 有志レポジトリの見つけ方
ネット検索や X の TL から地道に見つける必要があります。

----

**これだけだと途方に暮れるかと思いますので、調べ方の一例を紹介します**。
言語ランタイムに関しては、[devenv](https://github.com/cachix/devenv) というツールのソースコードを読むと探しやすいです。

例えば、Python について調べる場合、[リファレンスの Python 設定一覧ページ](https://devenv.sh/languages/python/#languagespythonversion)を開き、バージョンを指定する設定項目を探します。

![Python の例](/images/1c0373f3570334/tips-03/tips-03-2026-3-6.webp)

記述されている[ソースコード（`Declared by:...`）](https://github.com/cachix/devenv/blob/main/src/modules/languages/python/default.nix)を開きます。

nix ファイル（`default.nix` など）にて、`github` や `cachix` と書かれている箇所が大抵はあるはずです。

```nix:src/modules/languages/python/default.nix
  nixpkgs-python = config.lib.getInput {
    name = "nixpkgs-python";
    url = "github:cachix/nixpkgs-python";
    attribute = "languages.python.version";
    follows = [ "nixpkgs" ];
  };
```

**コードより、devenv は `cachix/nixpkgs-python` という GitHub リポジトリを利用して Python のバージョンを指定していると推測できます**。

`cachix/nixpkgs-python` で検索し、[公式のドキュメント](https://github.com/cachix/nixpkgs-python)を参考にすれば `flake.nix` での使い方が分かります。

:::message
Nix の利点は、他者が公開している `flake.nix` や Nix をベースとしたツールのソースコードが読みやすい & 真似しやすい事だと思います。

Nix 言語だけ知っていれば、これらのソースコードも読めるため、学習コストが低く済みます（他言語を幅広く学ぶことなく、Nix 言語という単一の知識を流用できるため。なお Nix 言語自体の学習コストは...ちょっと大変かもしれません）。
:::


## 3.2 通常の方法
大抵のパッケージは先ほどのような有志レポジトリは存在しません。

この場合、`overrideAttrs` や `overlays` といった関数を用いて設定を書く必要があります。
ビルドに使うソースを変更することで最新のパッケージをビルドする方法です。

:::message
**Nix 言語で設定を記述する必要があり、手間がかかります**。
**Nixpkgs にあるソースコード（`default.nix`）を読み、適切な書き方を判断する必要があり、ハードルが高いかもしれません**。
:::

詳細はこちらで解説しています。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/tips-04


## 3.3 第三の選択肢
先述の `overrideAttrs` は手軽な方法とは言えません。
Nixpkgs に最新版が反映されるのを待つ方がいいかもしれません。

**どうしても最新版が必要、かつ、煩雑な手順を避けたい場合、Nix 以外の方法で対応するのも手です**。

例えば、プロジェクト専用の開発環境（devShell）内に mise などのパッケージマネージャーを Nix で用意し、一部パッケージのインストールはそれらを経由して行うというアプローチです。


:::message
**私の場合、Python のライブラリは uv で管理する方針にしています**。

Nix でも Python ライブラリを導入可能です。
しかし、網羅性や更新速度は完璧とは言えません（マイナーなライブラリは顕著）。

**環境の再現性のために過剰な運用コストとなっては元の子もないので、Nix に固執する必要性は無いと思います**。

そのため、devShell で特定のプロジェクト専用の uv を用意して、uv 経由で Python ライブラリを管理しています。
一方でライブラリ以外（Python 本体、uv、その他のパッケージ）は Nix に任せるといった使い分けをしています。
:::


# 4. 過去バージョンを利用したい場合
## 4.1 通常の方法
Nix では Nixpkgs のリビジョンを固定することでパッケージのビルドレシピを固定し、結果としてパッケージのバージョンを固定します。

Nixpkgs を固定する仕様上、パッケージ全体が一定のバージョンに固定されます。
`nix flake update` した場合は Nixpkgs のリビジョンが最新に変わるため、パッケージ全体のバージョンが変わります。

**一部のパッケージだけ古いバージョンのままにしつつ、他を更新するには特別な書き方をする必要があります**。

具体的には、`flake.nix` で Nixpkgs を複数定義し、パッケージ A 用とその他用に分ける運用となります。
この際、どの Nixpkgs のリビジョンがパッケージ A の各バージョンに対応しているかを調べる必要があります。

詳細は以下で解説しています。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/tips-04

**次セクションでは、より手軽にバージョンを指定できる nix-versions を用いた方法を紹介します**。


## 4.2 nix-versions
[nix-versions](https://github.com/vic/nix-versions) はパッケージの各バージョン対応した Nixpkgs のリビジョンを調べるツールです。

```bash:Bash
$ nix run github:vic/nix-versions -- go
Name  Version    NixInstallable           VerBackend  
go    1.25rc2    nixpkgs/648f701#go_1_25  nixhub      
# 中略...
go    1.25.5     nixpkgs/a1bab9e#go       nixhub      
go    1.25.7     nixpkgs/80d901e#go       nixhub      
go    1.26.0     nixpkgs/80d901e#go_1_26  nixhub  
```

また、nix-versions を `flake.nix` に組み込むと簡単に特定バージョンのパッケージを指定できます。

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
nix-versions では、**Nixpkgs に登録されたことがあるバージョンのみ利用できます**。

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

**この場合、[最新バージョンを利用する例で紹介した方法](#3.-nixpkgs-未反映の最新バージョンを利用したい場合)を用いる必要があります**。
:::


:::message alert
**便利なので紹介しましたが、将来的には自力で Nixpkgs のリビジョンをピンする方法（詳細は[こちら](https://zenn.dev/trifolium/books/1c0373f3570334/viewer/tips-04)）に移行すべきだと個人的には思います**。

nix-versions を `flake.nix` の `inputs` に利用する方法では、[ntv](https://github.com/vic/ntv) が依存に含まれます。
ntv 自体は nix-versions と同じ作者なので支障はないと思いますが、余計なサードパーティ製ツールの依存が増えるのは（個人的には）気になります。

また、`inputs` の記述でわかる通り、`https://nix-versions.oeiuwq.com/flake.zip/go@1.25.5` をダウンロードして使用します。
Nixpkgs に置かれているファイルを信用するのは Nix を利用する上で事実上避けられない、かつ、OSS で監視の目も多いはずと割り切れます。
一方、nix-versions は利用者自身が内部挙動に注意を払う必要性があると思います。
つまり、私の視点から見ると `flake.nix` の記述は楽できるが、nix-versions 自体の信頼性を常に意識するという運用コストがあると思います。

これらの理由から、私は古典的な方法で Nixpkgs をピンする方針にしています。

>とはいえ、この考え方は神経質なだけかもしれないので、本章では取っ付きやすさを優先して nix-versions を紹介しました。

:::
