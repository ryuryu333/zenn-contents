---
title: "Home Manager インストール後の初期設定"
---

# 1. この章でやること
この章では Home Manager を本格的に利用する前にすべき設定を解説します。


# 2. ロックファイル
インストールの過程で、`flake.lock` が自動的に生成されたはずです。

**このロックファイルで Home Manager 本体のバージョンや今後追加するパッケージのバージョンが固定されます**。

ユーザー環境の再現に必須なファイルなので、`git add` しておいてください。


# 3. シェルの設定
利用しているシェルにて Home Manager が作成した環境変数を利用可能にするため、以下を `~/.profile`（Bash）や `~/.zprofile`（Zsh）等に追記してください[^1]。

[^1]: 公式リファレンス > Installing Home Manager > Standalone installation > 4.: https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone

```bash
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
```


# 4. 利用する Nixpkgs のブランチ変更
インストール作業で自動生成された `flake.nix` の `inputs` では Nixpkgs の `nixos-unstable` ブランチが指定されています。

NixOS を利用する場合は `nixos-*` ブランチを使うべきですが、**それ以外の OS ならば `nixpkgs-*` ブランチを使うべきです**。


:::details 理由
**Nixpkgs ではブランチによって CI/CD のテスト内容が異なります**。
`nixos-*` ブランチは NixOS 用です。

NixOS 以外であっても問題はほぼ無いと思いますが、わざわざ `nixos-*` を使う理由はありません。

詳細はこちらで解説しています。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/common-06

:::

`flake.nix` を以下のように編集します。

```diff nix:flake.nix
  inputs = {
-   nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
+   nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
```

以下のコマンドで結果を反映させます。

```bash:Bash
home-manager switch --flake .
```


# 5. 設定ファイルの配置場所を変更
**このセクションの内容は好みの問題だと思うので、任意です**。

以下のように dotfiles における各種設定ファイルの責務を分離すると管理が楽だと思います。

`flake.nix` には入力情報の定義と各ツール（Home Manager 含む）のオーケストレーションを担わせます。
`home.nix` などの `*.nix` ファイルには具体的なユーザー環境に入れるパッケージのリストなどの情報を持たせます。

----

Home Manager インストール直後では、以下のようなファイル構成だと思います。

```:構成
dotfiles/
├── flake.lock
├── flake.nix
└── home.nix
```

今後、別のツールを導入する可能性を考慮すると、ツールごとにフォルダがあると便利です。

**また、`home.nix` が肥大化した際は `vim.nix` や `git.nix` のように関心ごとに設定ファイルを切り出していくことになります**。
このままではプロジェクトルートにファイルが散乱するので、この観点でもフォルダ分けをした方が良いです。

```:構成
dotfiles/
├─ flake.lock
├─ flake.nix
└─ home-manager/
    └─ home.nix
```

:::details 具体的な活用例
**`dotfiles/home-manager` にユーザー環境に関する設定を集約するイメージです**。

```:利用イメージ
dotfiles/
├─ ...
└─ home-manager/
    ├─ home.nix  # 内部で git.nix を参照
    ├─ git.nix  # git の設定ファイルの配置などを定義
    └─ git/
        └─ .gitconfig  # git の設定ファイル（コピー元）  
```

----

**また、PC ごとの設定を以下のように管理できたりします**。


```:利用イメージ
dotfiles/
├─ ...
└─ home-manager/
    ├─ git/
    ├─ bash/
    ├─ zsh/
    └─ home/
        ├─ common.nix  # 共通の設定 Git を参照
        ├─ wsl.nix  # WSL 専用の設定 Bash を参照
        └─ mac.nix  # Mac 専用の設定 Zsh を参照
```

----

Mac 限定ですが、Home Manager の他に nix-darwin というツールがよく利用されます（Mac のシステム設定を管理できるツールです）。

**どちらのツールも `flake.nix` を起点とします**。
そのため、以下のようなフォルダ分けにすると管理しやすいです。

```:利用イメージ
dotfiles/
├─ flake.nix
├─ home-manager/
│  └─ home.nix
└─ nix-darwin/
    └─ configuration.nix
```

----

より具体的な活用例が見たい場合はこちらの記事をご覧ください。

https://zenn.dev/trifolium/articles/b3d88bbabcad2c

:::

**`home.nix` を移動させた場合、`flake.nix` の内容を書き換える必要があります**。

```diff nix:flake.nix
    homeConfigurations."ryu" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
-     modules = [ ./home.nix ];
+     modules = [ ./home-manager/home.nix ];
    };
```

以下のコマンドで結果を反映させます。

```bash:Bash
home-manager switch --flake .
```
