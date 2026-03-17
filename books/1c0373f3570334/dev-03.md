---
title: "4.2 devShell を自動起動する - nix-direnv"
---

# 1. この章でやること
この章では、devShell の起動を自動化します。

:::message
**エディターでプロジェクトを開くだけですぐに開発作業ができて便利なので、実用上で必須かと思います**。
:::


# 2. direnv nix-direnv のインストール
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


# 2. シェルの設定
**direnv を利用するためにはシェルへフックを追加する必要があります**。

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

:::message
詳細は[公式ドキュメント](https://github.com/direnv/direnv/blob/master/docs/hook.md#)をご確認ください。
:::


# 3. 利用方法
`flake.nix` があるディレクトリを開き、`.envrc` を作成し、`use flake` と記入します。

```bash:Bash
echo "use flake" >> .envrc
```

その後、以下のコマンドを実行します。

```bash:Bash
direnv allow
```

以降、現在のディレクトリを開く度に devShell が自動で起動します。

```bash:Bash
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
