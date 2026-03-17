---
title: "4.1 Flakes devShell の基本な使い方"
---

# 1. この章でやること
この章では、devShell の基本的な使い方を解説します。

:::message
**最小構成で動かし、devShell の雰囲気に慣れるのが目的です**。

より実用的な使い方は次章以降で解説します。
また、設定ファイル（`flake.nix`）の細かい書き方も次章以降で扱います。
:::


# 2. 設定ファイルの作成
新規ディレクトリを作成し、`flake.nix` を作成し、以下の内容を記述します。

```nix:flake.nix
{
  description = "Example environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
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

`flake.nix` を Git 管理下にしてください。

```bash:Bash
git init
git add flake.nix
git commit -m "add flake.nix"
```


# 3. 環境の構築
以下のコマンドで devShell を構築し、開発用のシェル環境に入れます。

```bash:Bash
nix develop
```

:::message
hello パッケージそのもの、および、hello の依存パッケージのダウンロードが行われるため、時間がかかります。
**Nix にはキャッシュ機能があるので、2 回目以降の起動は 1 秒ほどで終わりかと思います**。
:::


# 4. 動作確認
hello コマンドが実行可能になっているはずです。

```bash:Bash
> hello
Hello, world!
```


# 5. バイナリはどこにあるのか？
hello の呼び出し元を確認すると、`nix/store/...` と表示されます。

```bash:Bash
$ which hello
/nix/store/4w6i1qx2k6g5bb7m2i2h1gfhk6kk7hnr-hello-2.12.2/bin/hello
```

:::message
**`usr/bin/` などの一般的な場所ではなく、`nix/store/` に隔離された場所へ hello は保管されています**。

**devShell では、一時的に PATH へ `nix/store/...hello...` が追加されたシェル環境を構築するため、hello コマンドが利用可能になります**。

<!-- cspell:disable -->

```bash:Bash
$ echo "$PATH" | tr ':' '\n' | grep hello
/nix/store/8qi947kixhz1nw83dkwxm6d0wndprqkj-hello-2.12.2/bin
```

<!-- cspell:enable -->

:::


# 6. 環境を抜ける
以下のコマンドで devShell 環境から抜けられます。

```bash:Bash
exit
```

:::message
**devShell を抜けると PATH が元に戻り、hello コマンドが見つからなくなります**。

```bash:Bash
$ echo "$PATH" | tr ':' '\n' | grep hello
# 何も表示されない

$ hello
Command 'hello' not found
```

:::


# 7. ロックファイルとパッケージの更新
devShell 環境を起動する際、自動的に `flake.lock` というファイルが生成されます。
**このロックファイルにより、パッケージのバージョンが固定されます**。

以下のコマンドで `flake.lock` を更新できます。

```bash:Bash
nix flake update
```

更新後、devShell を起動すると、更新されたロックファイルの内容に従ってパッケージがビルドされます。

```bash:Bash
nix develop
```

:::details 補足説明
Nix では、Nixpkgs にあるパッケージのビルドレシピを元にビルドを行います。

例えば、[Nixpkgs のここ](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/he/hello/package.nix)に hello パッケージが定義されています。

以下のように、どこからパッケージをダウンロードするのかが定義されています。

```nix:コード抜粋
  src = fetchurl {
    url = "mirror://gnu/hello/hello-${finalAttrs.version}.tar.gz";
    hash = "sha256-WpqZbcKSzCTc9BHO6H6S9qrluNE72caBm0x6nc4IGKs=";
  };
```

**hello が新しいバージョンになった際は、Nixpkgs にて「どのソースから構築するか」が変更されます**。

**そのため、Nixpkgs のどのリビジョン（コミットタイミング）の情報を参照するかを固定すると、hello パッケージ（とその依存パッケージ）のバージョンを固定できます**。

`flake.lock` には Nixpkgs のリビジョンが記載されており、`nix flake update` により最新のリビジョンに変更されます。
:::


# 8. パッケージの追加・削除
`packages` のリストを編集すると、パッケージを追加・削除できます。

```diff nix:flake.nix
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        hello
+       nixfmt       
      ];
    };
```

環境に入りなおすと、nixfmt が追加された環境となります。

```bash:Bash
exit
nix develop
```

パッケージの探し方は以下をご覧ください。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/common-06

:::message
**都度、環境に入りなおすのは面倒だと感じたかもしれません**。
**次章では、この環境の起動を自動化していきます（nix-direnv）**。
:::
