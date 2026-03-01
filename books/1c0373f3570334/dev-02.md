---
title: "Flakes devShell の使い方"
---

# 1. この章でやること
この章では、devShell を用いた開発環境の使い方を解説します。


# 2 必要なパッケージの準備
direnv を利用すると devShell の起動を自動化できます。
**エディターでプロジェクトを開くだけですぐに開発作業ができ便利なので、実用上で必須かと思います**。


## 2.1 direnv のインストール
[direnv](https://github.com/direnv/direnv) と [nix-direnv](https://github.com/nix-community/nix-direnv) を以下のいずれかの方法でインストールします。

##### Nix（Home Manager）でユーザー環境を管理している場合

```nix:home.nix
  home.packages = with pkgs; [
    direnv
    nix-direnv
    # その他のパッケージ...
  ];
```

##### Home Manager を使わない場合
Nix の profile 機能を使うと、ユーザー環境にパッケージをインストールできます。

```zsh:Zsh
nix profile install direnv
nix profile install nixpkgs#nix-direnv
```

他にも、apt や Homebrew でもインストールできます。


## 2.2 シェルの設定
direnv を利用するためにはシェルへフックを追加する必要があります。

シェルの設定ファイルに以下を追記してください。

```:~/.bashrc
eval "$(direnv hook bash)"
```

```:~/.zshrc
eval "$(direnv hook zsh)"
```

編集後、シェルを再起動してください。

```zsh:Zsh
exec $SHELL -l
```


# 3 設定ファイルの作成
新規ディレクトリを作成し、`flake.nix` を作成し、以下の内容を記述します。

```nix:~work/nix-demo/flake.nix
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

もしも、`flake.nix` が置かれているレポジトリが Git 管理されている場合、`flake.nix` を `add` してください。

```Zsh:Zsh
git init
git add flake.nix
```


# 4 環境の構築
以下のコマンドで devShell が自動起動するようになります。

```zsh:Zsh
echo "use flake" >> .envrc
direnv allow
```

初めて環境を構築する場合、十数秒ほどかかるかもしれません。

:::message
hello パッケージそのもの、および、hello の依存パッケージのダウンロードが行われるため、時間がかかります。
Nix にはキャッシュ機能があるので、2 回目以降の起動は 1 秒ほどで終わりかと思います。
:::


# 5 動作確認
hello コマンドが実行可能になっているはずです。

```zsh:Zsh
> hello
Hello, world!
```

hello の呼び出し元を確認すると、`nix/store/...` と表示されます。

```zsh:Zsh
$ which hello
/nix/store/4w6i1qx2k6g5bb7m2i2h1gfhk6kk7hnr-hello-2.12.2/bin/hello
```

`usr/bin/` などの一般的な場所ではなく、`nix/store/` に隔離された場所へ hello は保管されています。
devShell では、一時的に PATH へ `nix/store/...hello...` が追加されたシェル環境を構築するため、hello コマンドが利用可能になります。

そのため、devShell 環境から抜けると hello は `command not found` になります。

```zsh:Zsh
# direnv、nix-direnv の機能により
# プロジェクトディレクトを抜けると自動的に devShell 環境から抜けます
> cd ..
direnv: unloading

> hello
zsh: command not found: hello

# プロジェクトディレクトリに戻ると
# 自動的に devShell 環境へ入ります
> cd -
direnv: loading ~/work/test/.envrc
direnv: using flake
# ... その他ログ

> hello
Hello, world!
```


# 6 パッケージの更新
devShell 環境を起動する際、自動的に `flake.lock` というファイルが生成されます。
このロックファイルにより、パッケージのバージョンが固定されます。

以下のコマンドで `flake.lock` を更新できます。

```zsh:Zsh
nix flake update
```

direnv、nix-direnv により、自動的に devShell が再構築されます。


:::message
**`flake.nix` の仕様上、パッケージ全てが更新されます**。
:::

:::details 補足説明
Nix では、Nixpkgs にあるパッケージの構築レシピを元にビルドを行います。

[Nixpkgs では hello パッケージはどのソースから構築するか](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/he/hello/package.nix)が定義されています。
hello が新しいバージョンになった際は、Nixpkgs にて「どのソースから構築するか」が変更されます。

そのため、Nixpkgs のどのリビジョン（コミットタイミング）の情報を参照するかを固定すると、hello パッケージ（とその依存パッケージ）のバージョンを固定できます。

`flake.lock` には Nixpkgs のリビジョンが記載されており、`nix flake update` により最新のリビジョンに変更されます。
:::


# 7 パッケージの追加・削除
`packages` のリストを編集するだけで、パッケージを追加・削除できます。

```diff nix:flake.nix
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        hello
+       nixfmt       
      ];
    };
```

編集後、ターミナルで動かす（エンターキーを押すなど）と direnv、nix-direnv により、自動的に devShell が再構築されます。


# 8. 補足
## 8.1 その他の機能
`flake.nix` にて devShell という機能で開発環境を構築する方法を解説しましたが、他にも機能があります。

例えば、apps という機能はタスクランナーとして使えます。

```nix:flake.nix
apps.default = {
    type = "app";
    program = "${pkgs.hello}/bin/hello";
};
```

```zsh:Zsh
> nix run
Hello, world!
```

他にも機能があるので、興味がある方はリファレンスをお読みください。

https://wiki.nixos.org/wiki/Flakes


## 8.1 ローカルだけで使いたい場合
チームに導入はできないが、自分のローカルでは devShell を使いたい（リモートに `flake.nix` を push できない）場合について。

`flake.nix` を作成した後、以下を実行してください。

```zsh:Zsh
git add --intent-to-add flake.nix
git update-index --assume-unchanged flake.nix
```

`flake.nix` をローカルで追跡しつつ、ステージングしない & 変更を無視できます。
ただし、`git rebase` などの操作で破綻する可能性はあるので、お気をつけください（`git stash` `git stash pop` で対策はできる...はず）。


:::details 別の方法
先ほどの方法は `flake.nix` の仕様を逆手に取った裏技的な方法です。

**Nix に用意されている機能で丁寧に対策するなら、以下のような方法もあります**。

```zsh:Zsh
printf "\n/flake.nix\n" >> .git/info/exclude
echo "use flake path:." >> .envrc
direnv allow
```

`use flake` の場合、`nix develop` 相当のコマンドがディレクトリを開いた際に実行されます。
この際、Nix は Git 管理下のファイルのみを参照するため、`flake.nix` が見つからないとエラーになります。

`use flake path:.` とすると、`nix develop path:.` 相当のコマンドになります。
こうすると、Nix は `./` 全体を参照するため、エラーになりません。

**ただし、この方法の場合、Git 管理していないファイルも参照されるため、プロジェクトサイズが大きい場合、devShell 起動時間が長くなると思われます**。
:::
