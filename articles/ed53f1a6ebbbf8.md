---
title: "Nix 未使用ファイルを自動的に定期削除する"
emoji: "🦤"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [nix]
published: true
published_at: "2026-07-15 07:00"
---

# はじめに
Nix を使っているとデータ容量が圧迫されがちです。

一般的な対策は `nix-collect-garbage -d` で未使用ファイルを消すことです。

しかし、これだけでは十分に容量を削減し切れていません。
**nh というツールを用いると、より削減できます**。

- 筆者の環境の場合
  - 実行前の `nix/store` 容量：21 GB
  - `nix-collect-garbage -d` 実行後：11 GB
  - `nh clean all` 実行後：4.6 GB

:::details 実行時のログ
WSL 環境です。
home manager や flake devShell を普段利用しています。

```zsh:zsh
> du -sh /nix/store
27G     /nix/store

> nix-collect-garbage -d
# ...
note: hard linking is currently saving 1.6 GiB
19651 store paths deleted, 11.0 GiB freed

> du -sh /nix/store
11G     /nix/store
```

```zsh:zsh
 > nix-collect-garbage -d
 # ...

 > du -sh /nix/store
11G     /nix/store

> nh clean all
# ...
> Performing garbage collection on the nix store
6083 store paths deleted, 5.6 GiB freed

>  du -sh /nix/store
4.6G    /nix/store
```

:::


本記事では、nh の利用方法、及び、`nh clean` 定期実行の設定方法を紹介します。


# 前提

- Nix 導入済み
- （自動実行したいなら）home manager 導入済み


# nh

https://github.com/nix-community/nh

nh は、Nix、home manager などで利用するコマンドを、統一的なインターフェースで扱えるようにする CLI ツールです。

ビルド結果の表示や世代管理など複数の機能がありますが、**本記事では不要なデータを削除する `nh clean` のみを扱います**。
`nh clean` は `nix-collect-garbage` 相当の処理に加え、GC root の整理、削除条件の細かい指定が可能です。


# 使い方
以下のコマンドを実行すると、古い世代や GC root を削除した後、Nix store の gc を実行します。

```zsh:zsh
nh clean all
```

:::message alert
デフォルトでは、ビルド結果や direnv が作成したものを含む GC root も削除対象になります。
:::

`nh clean all` では、直近に使っていた開発環境のキャッシュも消えてしまうので不便です。
以下のように削除範囲を絞るのが実用的だと思います。

```zsh:zsh
nh clean all --keep-since 30d --keep-one
```

直近 30 日は残す、home manager 等の profile は直近 1 世代だけ残す、という挙動になります。
他にも `nh clean all --help` で多くのオプションが確認できたので、細かい調整もできそうです。


# 定期実行
home manager を利用すると、毎週自動で `nh clean` できます。

以下では、毎週、30 日以上使っていない不要なファイルを削除する設定にしました。

```nix:home.nix
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 30d --keep-one";
    };
  };
```


# さいごに
Nix は仕組み的に容量消費は避けられないので、**運用で無駄使いを無くす方向でカバーする**のが良いかなと思います。

細かい設定記述は私の dotfiles を AI に食わせてご確認ください。

https://github.com/ryuryu333/dotfiles
