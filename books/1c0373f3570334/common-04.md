---
title: "Nix のインストール"
---

# 1. この章でやること
この章では **Nix のインストール**を行います。


# 2. インストール手順
ワンコマンドで楽に Nix を導入できる Determinate Systems のインストーラーを利用します。

https://github.com/DeterminateSystems/nix-installer

以下を実行します。

```bash:Bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

>前章でも言及しましたが、本書では Flakes という機能を利用する前提で解説します。
このインストーラーを利用すると、Flakes の有効化など、便利な設定を自動で行ってくれます。

# 3. インストール確認
ターミナルを開き直してから、以下で確認します。

```bash:Bash
nix --version
```

以下の様にバージョンが表示されればインストール完了です。

```bash:Bash
nix (Determinate Nix x.xx.x) y.yy.y
```


# 4. 補足
## 4.1 Nix とは？
Nix は **再現性の高さ**が特徴のパッケージマネージャーです。
構築する環境を**純粋関数型言語 Nix** で**宣言的に記述**します。

慣れないうちはテンプレートを真似る・一部だけを改変する（ツールを追加するだけ等）で十分だと思います。
以下のように言語ごとの設定ファイル（`flake.nix`）を公開している人もいます。

https://github.com/the-nix-way/dev-templates

Nix 言語について基礎から学びたい方はこちらの本がおすすめです。

https://zenn.dev/asa1984/books/nix-introduction


## 4.2 インストーラーについて
Nix には様々なインストーラーが存在します。

- [公式](https://nixos.org/download/)
- [Determinate](https://github.com/DeterminateSystems/nix-installer)
- [Lix](https://lix.systems/install/)

公式のインストーラーと比べ、Determinate や Lix はアンインストールがしやすい、便利な機能を自動で有効にしてくれるといった利点があります。

人によって推奨するインストーラーが異なりますが、本書では比較的メジャーな Determinate を利用します。
興味が湧いたらそれぞれの違いを調べると良いと思います。


## 4.3 アンインストール、更新
インストーラーによってコマンドが異なります。

Determinate の場合は下記ページの `Upgrading Determinate Nix` や `Uninstalling` を参照してください。

https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#upgrading-determinate-nix
