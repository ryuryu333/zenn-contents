---
title: "flake.nix と devShell の書き方"
---

# 1. この章でやること
この章では、`flake.nix` にて devShell 定義するために必要な Nix 言語の文法や仕様を解説します。


:::message
**Nix に慣れてきて、自分好みに環境をカスタマイズしたいと思った際にお読みください**。

`flake.nix` でやっていることだけを見るとちょっと複雑な yml や JSON なのですが、真面目に Nix 言語を理解しようとすると少々ややこしいです。
:::


# 2. 最小構成での解説
前章で提示した `flake.nix` には様々なテクニックが内包されているため、作成過程を簡潔に説明するのは難しいです。
**そのため、まずは最小構成で devShell を定義してみます**。

```nix:flake.nix
{
  description = "Example environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };
    in
    {
      devShells.aarch64-darwin.default = pkgs.mkShell {
        packages = [
          pkgs.hello
        ];
      };
    };
}
```

:::message
**`pkgs = import nixpkgs { system = "aarch64-darwin"; };` は自身の環境に合わせて変更してください**。

```:system 例
"x86_64-linux"
"aarch64-linux"
"x86_64-darwin"
"aarch64-darwin"
```

:::


devShell 環境を立ち上げると、hello を利用可能になります。

```bash:Bash
> nix develop

(nix:nix-shell-env) bash-5.3 $ which hello
/nix/store/4w6i1qx2k6g5bb7m2i2h1gfhk6kk7hnr-hello-2.12.2/bin/hello
```

それでは、`flake.nix` の記述を要素ごとに解説していきます。


## 2.1 description
ここは任意です。

```nix:flake.nix
  description = "Example environment";
```


## 2.2 inputs
**`inputs` には `flake.nix` にて利用する外部依存を記述します**。

今回の例だと、hello パッケージのビルドレシピを Nixpkgs という GitHub レポジトリから取得します。

Nixpkgs の内容は `nix develop` するタイミングによって変動し得ます。
そこで、`flake.nix` では参照する Nixpkgs のリビジョンをロックファイル（`flake.lock`）で固定します。


```nix:flake.nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
```

:::message
多くの場合、GitHub レポジトリを `inputs` に指定するかと思います。

Nix Flakes に対応していない（`flake.nix` がない）レポジトリを扱うこともあります。
例えば、[nix-homebrew](https://github.com/zhaofengli/nix-homebrew) では cask の定義をピンするために使っています。

>`flake.nix` がないレポジトリを参照する際、`flake = false` とします。

```nix
homebrew-cask = {
  url = "github:homebrew/homebrew-cask";
  flake = false;
};
```

:::


## 2.3 outputs
### 2.3.1 概要
**`outputs` には devShell などの各機能で参照する情報を定義します**。

`nix ~` のコマンドごとに参照する `outputs` が変わります。
例えば、`nix develop` を実行すると `outputs` の `devShell.<system>.default` が参照されます。

```nix:flake.nix
{
  outputs =
    { self, nixpkgs }:
    {
      # nix develop で参照される情報
      devShells.aarch64-darwin.default = pkgs.mkShell {
        # ...
      };
    };
}
```

:::details その他の outputs
**他にも、各種コマンドに対応した `outputs` の設定項目があります**。

```nix
# nix build
packages.<system>.default

# nix run
apps.<system>.default = ...
```

他にも様々な定義が[ NixOS の Flakes > Output schema](https://wiki.nixos.org/wiki/Flakes) にまとめられています。
:::


### 2.3.2 引数と式
`outputs` は Nix 言語の関数として定義します。

Nix 言語における関数は `<関数名> = <引数>: <式>` で表されます（cf. [nix-pills/05-functions-and-imports](https://nixos.org/guides/nix-pills/05-functions-and-imports.html)）。

```nix
> double = value: value * 2

> double 3
6
```

Nix 言語では複数の変数の集まり（[Attribute Set](https://nix.dev/manual/nix/2.18/language/values.html?highlight=attribute%20set#attribute-set)）を以下のように表記できます。


```nix
{
  value1 = 3;
  value2 = 7;
}
```

そのため、このような関数も定義できます。

```nix
> double = { value1, value2 }: value1 * value2

> double { value1 = 3; value2 = 7; }
21
```

`outputs` では、`{ self, nixpkgs }` が引数、それ以降が式となっています。
式の中で `devShells.aarch64-darwin.default` などの変数を定義し、それらの集まり（Attribute Set）を `outputs` に返しています。

```nix:flake.nix
  outputs =
    { self, nixpkgs }:
    {
      # ...
      devShells.aarch64-darwin.default = pkgs.mkShell {
        # ...
      };
    };
```

:::message
`flake.nix` の仕様として、`outputs` には引数として `inputs` で定義した変数（`nixpkgs` など）が渡されます。
また、`self` という `flake.nix` 自身を表す特別な変数も渡されます。

そのため、上記例では `{ self, nixpkgs }` を引数として定義しています。
`{ self }` と記述して `nix develop` するとエラーになります。

```nix
> nix develop
# ...
error: function 'outputs' called with unexpected argument 'nixpkgs'
# ...
```

人によっては `{ nixpkgs, ... }` と書く方もいます。
こう書くと、式の中で `self` を参照できませんが、`nix develop` してもエラーは起こりません（cf. [ellipsis](https://nix.dev/manual/nix/2.21/language/constructs)）。

>個人の好みですが、私は引数が暗黙的になるので使用は最低限にしています。

:::


### 2.3.3 let-in
変数の束縛に利用する構文です。
let で変数を宣言・初期化し、in で変数を利用できます。

```nix
let
  value = 2;
in
  value * 3
# -> 6
```

:::details 変数参照の仕様
let では、変数同士が参照できます。

```nix
let
  value1 = 2;
  value2 = value1 * 2;
in
  value1 * value2
# -> 8
```

一方、in ではできません。

```nix
let
  value = 2;
in
  { hoge = value * 3; }
# -> { hoge = 6; }

let
  value = 2;
in
  {
    hoge = value * 3;
    fuga = value * 2;
  }
# ->
# {
#   fuga = 4;
#   hoge = 6;
# }

let
  value = 2;
in
  {
    hoge = value * 3;
    fuga = hoge * 2;
  }
# -> error: undefined variable 'hoge'
```

実は [rec キーワード](https://nix.dev/manual/nix/2.21/language/constructs#recursive-sets)を使うと可能になったりします。
とはいえ、基本的には let で前準備をして、in では用意した変数を当てはめるだけ、という使い方をした方が読みやすいと思います。

```nix
let
  value = 2;
in
  rec {
    hoge = value * 3;
    fuga = hoge * 2;
  }
# ->
# {
#   fuga = 12;
#   hoge = 6;
# }
```

:::

下記 `outputs` では、let で変数 `pkgs` を宣言し、in で利用しています。

```flake.nix
  outputs =
    { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };
    in
    {
      devShells.aarch64-darwin.default = pkgs.mkShell {
        packages = [
          pkgs.hello
        ];
      };
    };
```

Nixpkgs からパッケージのビルドレシピを取得する際、どの OS 用であるかの情報が必要とされます。
そのため、以下のように `system = <OS と CPU アーキテクチャ>` を渡しています。

```nix
  pkgs = import nixpkgs { system = "aarch64-darwin"; };
```

`pkgs.hello` と参照すると、Nixpkgs から `aarch64-darwin` 用の hello パッケージのビルドレシピを取得できます。


## 2.4 devShells
### 2.4.1 system と name
`outputs` では devShell を `devShells.<system>.<name>` のように定義します。

`<system>` は `aarch64-darwin` などの OS 情報を定義します。
`nix develop` を実行した際、自動的にホスト OS 情報が渡されます。
例えば、MacBook Pro M1 で実行すると、`devShells.aarch64-darwin.<name>` が自動的に参照されます。

`<name>` を用いると devShell を複数定義でき、`nix develop .#<name>` のように呼び出します。

```nix:flake.nix
devShells.aarch64-darwin.default = ...;
```

:::message
`default` は特別な name です。

`nix develop .#default` を実行すると、`devShells.<system>.default` が参照されます。

このコマンドは以下のように短縮可能です。

```nix
nix develop .#default
nix develop .
nix develop
```

:::



:::details 複数の devShell を定義する書き方のパターン
以下の例では、`nix develop .#myEnv` で呼び出せる devShell を定義しつつ、`nix develop`（default）でも同じ環境を使えるように定義しています。

```nix:flake.nix
      devShells.x86_64-linux = {
        myEnv = pkgs.mkShell {
          packages = [
            pkgs.hello
          ];
        };
        default = self.devShells.x86_64-linux.myEnv;
      };
```

**他にも様々な書き方があります**。


#### パターン 1
**LLM を利用すると、この書き方を提示される印象です**。
個人の好みの問題ですが、副作用が強いコードなので避けるべきだと思っています。

```nix:flake.nix
      devShells.x86_64-linux = rec {
        myEnv = pkgs.mkShell {
          packages = [
            pkgs.hello
          ];
        };
        default = myEnv;
      };
```

`rec` キーワードを利用すると、再帰的な参照が可能になります。
この例の場合、`devShells.x86_64-linux.*` 全体が対象となり、意図しない参照が起こり得ます。
**`devShells` は複雑になりがちなので、`rec` で余計に複雑さを上げる必要性は無いと思います**。


#### パターン 2
`let in` を使った書き方です。

```nix:flake.nix
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      myEnv = pkgs.mkShell {
        packages = [
          pkgs.hello
        ];
      };
    in
    {
      devShells.x86_64-linux = {
        inherit myEnv;
        default = myEnv;
      };
    };
```

一番お行儀が良い書き方かもしれません。
`let` で事前にどのようなシェル環境であるかを定義し、`in` で利用するだけ、とシンプルな記述にできます。

**`flake.nix` が肥大化してきたら、この書き方を意識すると、読みやすい設定になるかと思います**。
:::


# 2.4.2 mkShell
**`devShells.<system>.<name>` には Derivation を渡す必要があります**。
**Derivation は先ほどから何度も使っている「ビルドレシピ」のことです**。

Nix 言語では `pkgs.hello` のように hello パッケージのビルドレシピを Derivation と呼びます。
また、複数のパッケージを内包した環境をビルドレシピのことも Derivation と表現します。

>大雑把な整理ですが、何らかの環境を構築するための関数は大抵 Derivation を引数とします（その環境を作るために必要な依存を Derivation として受け取る）。
そして、環境全体のビルドレシピを Derivation として返します。

```nix:flake.nix
{
    devShells.aarch64-darwin.default = pkgs.mkShell {
      packages = [
        pkgs.hello
      ];
    };
};
```

この記述の場合、`mkShell` 関数を利用しており、`pkgs.hello` を「packages」として持つ「shell」を構築する Derivation が計算されます。


# 3. 保守性を高めた書き方に変更する
先ほどの `flake.nix` はあえて冗長、かつ、マジックナンバー上等といったスタイルで書いていました。
これを書き換えていきます。

**まず、OS 情報を `system` として切り出します**。

```diff nix
  let
-   pkgs = import nixpkgs { system = "aarch64-darwin"; };
+   system = "aarch64-darwin";
+   pkgs = import nixpkgs { system = system; };
  in ...
```

[inherit キーワード](https://nix.dev/manual/nix/2.18/language/constructs#inheriting-attributes)を用いて、`system = system` を簡易化します。

```diff nix
  let
    system = "aarch64-darwin";
-   pkgs = import nixpkgs { system = system; };
+   pkgs = import nixpkgs { inherit system; };
  in ...
```

次に、in 側の記述も書き換えます。
`devShells.aarch64-darwin.default` の OS 情報を `system` にします。

>Nix 言語では `${var}` で文字列の展開をできます。

```diff nix
- devShells.aarch64-darwin.default
+ devShells.${system}.default
```

`packages` のリストにて複数のパッケージを宣言すると `[pkgs.a pkgs.b pkgs.c]` のように `pkgs.*` が連続します。

[with](https://nix.dev/tutorials/nix-language.html#with) を利用すると、`pkgs` を省略できます。

```diff nix
- packages = [
-   pkgs.hello
- ];
+ packages = with pkgs; [
+   hello
+ ];
```

----

最終的に以下のようになります。

```nix:flake.nix
{
  description = "Example environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          hello
        ];
      };
    };
}
```


# 4. 複数 OS に対応した書き方に変更する
devShell を定義する際、OS ごとに記述するのは面倒です。

**[flake-utils](https://github.com/numtide/flake-utils) を利用すると、簡単に複数 OS に対応した定義を記述できます**。

```diff nix:flake.nix
{
  description = "Example environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
+   flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
+     flake-utils,
    }:
+   flake-utils.lib.eachDefaultSystem (
+     system:
      let
+       pkgs = nixpkgs.legacyPackages.${system};
      in
      {
+       devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            hello
          ];
        };
      }
+   );
}
```

`flake-utils.lib.eachDefaultSystem` を利用すると、`"x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"` 用の定義を一括で作成できます。


::::::details 関数挙動の補足
`flake-utils.lib.eachDefaultSystem` には `system` を引数とし、Attribute Set を返す無名関数を渡す必要があります。

```nix
{
  devShells.default = ...;
}
```

このような Attribute Set を無名関数にて返すよう定義すると、`flake-utils.lib.eachDefaultSystem` により Attribute Set に `<system>` が挿入されます。

```nix
{
  devShells.<system>.default = ...;
}
```

:::message
`eachDefaultSystem` では `["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]` を `<system>` として挿入します。

```nix
{
  devShells.x86_64-linux.default = ...;
  devShells.aarch64-linux.default = ...;
  devShells.x86_64-darwin.default = ...;
  devShells.aarch64-darwin.default = ...;
}
```

:::

挿入される `<system>` はカスタマイズできます。
`eachDefaultSystem` を使うと上記の通り `flake-utils` が定義しているリストが使われます。

`eachSystem` を用いるとシステムリストを自分で定義できます。
::::::


**個人の好みの問題ですが、私は `eachSystem` を用いた書き方の方が好みです**。


:::details 理由
`eachDefaultSystem` を使うと対応システムが暗黙的になり、かつ、実際にビルドを動かしているシステムが不明瞭になるのが気になります。

**flake-utils は、`devShells.<system>.default` のように `<system>` を挿入する処理であり、ビルドの成否は保証されません**。
実際に使っているシステムを明示する方が宣言的、かつ、動くことを保証していると伝わるので良いと思っています。

>`eachDefaultSystem` を使う場合、`nix flake check --all-systems` で各システムにて評価エラーが起こるかをチェックできます。
とはいえ、律儀に毎回このチェックをする人は少ないと思います（実際、私は検証していなかったです）。

:::


```nix:flake.nix
{
  description = "Example environment";

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
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            hello
          ];
        };
      }
    );
}
```


# 5. 参考資料

https://wiki.nixos.org/wiki/Flakes

https://nix.dev/manual/nix/2.28/command-ref/new-cli/nix3-flake.html
