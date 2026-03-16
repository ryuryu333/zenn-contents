---
title: "Home Manager へ既存パッケージを移行する"
---

# 1. この章でやること
この章では、既存のパッケージマネージャで入れていた Git を Home Manager に移行する流れを解説します。

>Homebrew を例に説明しますが、他のパッケージマネージャでも同様の流れです。


# 2. 最終形のイメージ
Home Manager の設定は `~/work/dotfiles/home-manager` に集約します。

```:フォルダ構成
~/work/dotfiles/
├─ flake.lock
├─ flake.nix
└─ home-manager/
    ├─ git
    │   └─ .gitconfig
    └─ home.nix
```


# 3. Git を Home Manager で管理する
## 3.1 home.nix に Git を追加
`home.nix` に Git を追加します。

```nix:home.nix
  home.packages = with pkgs; [
    git
  ];
```

反映します。

```bash:Bash
home-manager switch --flake .
```


:::message
Homebrew と競合しないので、まだ Homebrew の Git をアンインストールしなくても大丈夫です。

移行が確認できてからアンインストールします。
:::


## 3.2 Git の設定ファイルを一緒に管理する
`home-manager/git/.gitconfig` を作成し、既存の設定をコピペしておきます。

`home.nix` にて以下のように記述します。

```nix:~/.config/home-manager/home.nix
  home.file = {
    ".gitconfig".source = ./git/.gitconfig;
  };
```

:::message
すでに `~/.gitconfig` があった場合、home-manager が配置しようとする `.gitconfig` と競合します。

```bash:Bash
$ home-manager switch --flake .
Existing file '/home/ryu/.gitconfig' would be clobbered
```

以下のコマンドを利用すると、既存の `~/.gitconfig` を `<filename>.backup` に置き換えてくれます。

```bash:Bash
home-manager switch -b backup
```

もしくは、既存の `~/.gitignore` を手動で削除（不安ならリネームでバックアップ）してください。

```bash:Bash
rm ~/.gitconfig
```

:::

Home Manager の設定を反映します。

```bash:Bash
home-manager switch --flake .
```


# 4. Homebrew 版を削除する
削除前に、home-manager 管理の Git が利用できるかを確認します。

```bash:Bash
which git
```

以下のように `.nix-profile` と記述されていたら問題なしです。

```bash:Bash
/Users/ryu/.nix-profile/bin/git
```

>Homebrew の方が表示された場合、`which -a git` を試してみてください。
`/Users/ryu/.nix-profile/bin/git` が含まれていれば Home Manager 管理下の Git は入っています。

Homebrew 管理の Git を削除します。

```bash:Bash
brew uninstall git
```


# 5. 以降は順次移行する
この章では Git を移行しました。
同じ手順で、Homebrew で入れていたツールを **ひとつずつ移行**していきます。

移行の際は以下のサイトでツールが Nix で利用可能か検索してください。

https://search.nixos.org/packages

パッケージの探し方や Nixpkgs に登録されていなかった場合の対処法はこちらをお読みください。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/common-06
