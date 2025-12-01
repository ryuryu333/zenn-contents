---
title: "home-manager で WSL と Mac の dotfiles を一括管理する"
emoji: "🐚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: []
published: false
---

# はじめに
私は home-manager というツールでメイン PC（WSL）のユーザー環境を管理しています。

ここ最近、MacBook を購入した為、Mac も一緒に管理したいと考えました。
しかし、**OS が違うこともあり、個別の設定が多く存在し、1 つの `home.nix` を使いまわすのは困難でした**。

**単独の dotfiles 管理レポジトリで 2 つのユーザー環境を手軽に管理したいと思い試行錯誤した結果、良さげな方法を見つけたので記事にまとめます**。

大まかに紹介すると、`flake.nix` にて `homeConfigurations.user@hostname` を利用します。
**`home-manager switch` 実行時に環境を自動判定して、適切な設定ファイルが適用されるようにできます**。

```bash:WSL
$ home-manager switch
# `common.nix` と `wsl.nix` に基づいて環境が構築される
```

```bash:Mac
$ home-manager switch
# `common.nix` と `mac.nix` に基づいて環境が構築される
```

>※ `wsl.nix` などの中身は `home.nix` と同じ構造です。


# 想定読者

- home-manager で複数の環境を管理したい方
- home-manager を Flakes で管理している方
  - `flake.nix` を利用するため、nix-channel でインストールした方は対象外です

Flakes への移行はこちらの記事を参照ください。

https://zenn.dev/trifolium/articles/dafb565c778ed5

# 検証環境

- Windows 11
  - WSL2 Ubuntu 22.04.5 LTS
  - nix (Determinate Nix 3.8.2) 2.30.1
- MacBook Pro M1
  - nix (Determinate Nix 3.11.3) 2.31.2

どちらも Flakes 機能を有効化済み、かつ、Flakes を利用した Standalone installation で home-manager を導入済み。


# 設定方法

WSL、Mac 用のユーザー環境を定義するという仮定で、以下の作業していきます。

- 共通した設定を定義したファイルの作成（`common.nix`）
- 環境独自の設定を定義したファイルの作成（`wsl.nix`、`mac.nix`）
- 各環境の `USER` と `HOSTNAME` を確認
- `flake.nix` を編集
- `home-manager switch` で反映、完了！


## 1. 共通した設定を定義したファイルの作成



## 2. 環境独自の設定を定義したファイルの作成



## 3. 各環境の `USER` と `HOSTNAME` を確認



## 4. 環境の反映



# 他の方法

軽く調べましたが、どの方法も自分の中の理想と合致しませんでした。

#### 1. dotfiles レポジトリを OS 毎に作り、`home.nix` を用意する

- WSL と Mac で共通した設定を使いまわせない、管理コストが大きい


#### 2. 単独の dotfiles レポジトリで `home.nix` を用意し、if 文で頑張る

- 美しくない（主観）
  - 同じファイルに複数環境の記述を混在させるのは可読性が悪いと感じる
- 参考：「OS ごとの分岐を書きたいのだけれど？」項

https://apribase.net/2023/08/22/nix-home-manager-qa/

#### 3. 単独の dotfiles レポジトリで `wsl.nix`、`mac.nix` を用意する

- `home-manager switch` コマンドの引数指定が必要となり、手間がかかる
- 参考：「良い感じにしてみる」項

https://zenn.dev/ymat19/articles/beac3c1beccac4#%E8%89%AF%E3%81%84%E6%84%9F%E3%81%98%E3%81%AB%E3%81%97%E3%81%A6%E3%81%BF%E3%82%8B





