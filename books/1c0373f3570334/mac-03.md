---
title: "nix-darwin の基本的な使い方"
---

# 1. この章でやること
この章では nix-darwin の基本的な使い方を解説します。


# 2. 最小構成で動かす
本セクションでは、操作例として 1 つだけ Mac のシステム設定を変更します。

:::message
具体的には、sudo コマンドの認証に Touch ID を利用できるように設定します。

通常、[macOS Sonomaのエンタープライズ向けの新機能](https://support.apple.com/ja-jp/109030)に記述されている通り、`/etc/pam.d/sudo_local` を作成・編集する必要があります。

```:参考 コマンド例
sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
sudo vim /etc/pam.d/sudo_local
```

```zsh:Zsh
> cat /etc/pam.d/sudo_local
# sudo_local: local config file which survives system update and is included for sudo
# uncomment following line to enable Touch ID for sudo
auth       sufficient     pam_tid.so
```

新しい Mac を買うたびに上記操作をするのは面倒です（そもそも、このような設定をしたことを忘れているかもしれません）。

nix-darwin を用いて、この設定をテキストで宣言的に記述・管理していきます。
:::


## 2.1 設定ファイルを編集する
`security.pam.services.sudo_local.touchIdAuth = true;` を `configuration.nix` に追記します。

```diff nix:configuration.nix
  {
    pkgs,
    ...
  }:
  {
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
    nix.enable = false;
+   security.pam.services.sudo_local.touchIdAuth = true
  }
```


## 2.2 反映する
`flake.nix` を配置しているディレクトリ（`~/work/dotfiles`）にて以下を実行します。

```zsh:Zsh
sudo darwin-rebuild switch --flake .
```


# 2.3 確認
`/etc/pam.d/sudo_local` を確認すると、以下のように設定が反映されているはずです。

```zsh:Zsh
# switch 前
> cat /etc/pam.d/sudo_local

# switch 後
> cat /etc/pam.d/sudo_local
auth       sufficient     pam_tid.so
```


:::message
nix-darwin では他にも様々な設定が記述できます。
[公式ドキュメント](https://nix-darwin.github.io/nix-darwin/manual) に設定一覧が記載されています。

ドキュメントはかなりの長さですので、リファレンスとして利用してください。
どのような設定があるかは、他者の dotfiles であったり、次章で紹介する設定例を参考にするのが良いかと思います。

----

ちなみに、今回使った設定は[公式ドキュメントの security.pam.services.sudo_local.touchIdAuth](https://nix-darwin.github.io/nix-darwin/manual/#opt-security.pam.services.sudo_local.touchIdAuth) に記載されています。
:::


# 3. システム設定のバージョン管理
## 3.1 世代の確認
以下のコマンドで世代一覧を確認できます。
古いものから順に表示されるため、`tail` で最近の世代だけ表示させています。

```zsh:Zsh
sudo darwin-rebuild --list-generations | tail -n 5
```

```zsh:Zsh
> sudo darwin-rebuild --list-generations | tail -n 5
  1    yyyy-mm-dd hh:mm:ss   
  2    yyyy-mm-dd hh:mm:ss   
  3    yyyy-mm-dd hh:mm:ss   
  4    yyyy-mm-dd hh:mm:ss   
  5    yyyy-mm-dd hh:mm:ss   (current)
```


## 3.2 ロールバック
1 つ前の世代に戻りたい場合、以下を実行します。

```zsh:Zsh
sudo darwin-rebuild --rollback
```

特定の世代も指定できます。

```zsh:Zsh
sudo darwin-rebuild --switch-generation <generation>
```

#### コマンド実行例

```zsh:Zsh
> sudo darwin-rebuild --rollback

> sudo darwin-rebuild --list-generations | tail -n 5
  1    yyyy-mm-dd hh:mm:ss   
  2    yyyy-mm-dd hh:mm:ss   
  3    yyyy-mm-dd hh:mm:ss   
  4    yyyy-mm-dd hh:mm:ss   (current)
  5    yyyy-mm-dd hh:mm:ss   

> sudo darwin-rebuild --switch-generation 3

> sudo darwin-rebuild --list-generations | tail -n 5
  1    yyyy-mm-dd hh:mm:ss   
  2    yyyy-mm-dd hh:mm:ss   
  3    yyyy-mm-dd hh:mm:ss   (current)
  4    yyyy-mm-dd hh:mm:ss   
  5    yyyy-mm-dd hh:mm:ss   
```


## 3.3 システム構築情報の記録
### 3.3.1 configurationRevision の設定
nix-darwin には、現在のシステム環境がどの Git コミット（リビジョン）から構築されたかを記録する仕組みがあります。


:::message
`flake.nix` や `configuration.nix` などを含むリポジトリの情報が対象となります。
本書では dotfiles リポジトリとして管理していることを前提に記述しています。
:::

**環境が壊れた際、どこの変更が原因であったかの調査等に有用かと思うので、設定に加えるのをお勧めします**。
`configuration.nix` と `flake.nix` を以下のように編集します。

```diff nix:configuration.nix
  {
+   self,
    pkgs,
    ...
  }:
  {
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
    nix.enable = false;
+   system.configurationRevision = self.rev or self.dirtyRev or null;
  }
```

```diff nix:flake.nix
    outputs =
-     {
-       nixpkgs,
-       home-manager,
-       nix-darwin,
-       ...
-     }:
      {
+       self,
+       nixpkgs,
+       home-manager,
+       nix-darwin
+     }:
      {
        darwinConfigurations."MacBook" = nix-darwin.lib.darwinSystem {
+         specialArgs = { inherit self; };
          modules = [ ./nix-darwin/configuration.nix ];
        };
      };
```


::::::details self ってなに？
**`self` は Flakes 特有の仕組みです**。
`flake.nix` において `self` は自動的に定義される特別な変数であり、`self` 経由で様々なメタデータを取得できます。

**例えば、`self.rev` で `flake.nix` が管理されているリポジトリのコミット位置（リビジョン）を取得できます**。

:::message
ここで取得されるリビジョン情報は `nix flake metadata --json` を `dotfiles` ディレクトリにて実行すれば `revision` という欄で確認できます。

```zsh:Zsh
> nix flake metadata --json
{
# 中略...
  "revision": "74dd96960fa1be335e96a8790d034f58e6b9ecb8",
  "url": "git+file:///Users/ryu/work/dotfiles?ref=refs/heads/main&rev=74dd96960fa1be335e96a8790d034f58e6b9ecb8"
}
```

:::


`configuration.nix` にて `self` を利用しています。

```nix:configuration.nix
system.configurationRevision = self.rev or self.dirtyRev or null;
```

これにより、dotfiles レポジトリのリビジョンを取得して、nix-darwin 側でログを保存しています。

>`self.rev` は Clean（全てコミット済み）な状態が前提です。
上記コードでは、未コミット時は `self.dirtyRev` からハッシュ値を取得しています。
どちらも取得できない場合は、null となります。

::::::


:::details specialArgs ってなに？
nix-darwin の仕組み（`nix-darwin.lib.darwinSystem`）として、`specialArgs` で定義された変数は `modules` に渡されます。

>Nix 言語の用語を使って言い直すと、`specialArgs` のアトリビュートセットが `modules` に定義されている関数の引数として渡されます。

`configuration.nix` にて `self` を利用するために、`specialArgs` を利用しています。
:::



:::details configuration.nix で self を利用するための記述方法
以下のように `configuration.nix` を記述した場合を考えます。

```diff nix:configuration.nix
  {
    pkgs,
    ...
  }:
  {
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
    nix.enable = false;
+   system.configurationRevision = self.rev or self.dirtyRev or null;
  }
```

**この場合、`system.configurationRevision` にて `self` が見つからない！とエラーが発生します**。

`self` は `flake.nix` 独自の変数であるため、`flake.nix` 以外からは見えません。
そのため、nix-darwin の仕組みである `specialArgs` を使い、`configuration.nix` に `self` を渡しました。

**しかし、これだけでは `configuration.nix` 側で利用できません**。
**`configuration.nix` にて引数を明示する必要があります**。

```diff nix:configuration.nix
  {
+   self,
    pkgs,
    ...
  }:
  {
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
    nix.enable = false;
+   system.configurationRevision = self.rev or self.dirtyRev or null;
  }
```

上記コードでは、引数として `self` を受け取り、利用すると宣言しています。

>Nix 言語において、`{}:{}`（<引数>:<式>）で関数を定義できます。
上記では引数側に `self` を追加しました。
>nix-darwin の仕様として、`lib`、`config`、`pkgs` はデフォルトで `modules` に指定した `*.nix` へ渡されます。
`self` は対象外なので、`specialArgs` を利用して明示的に渡す必要があります。

----

>引数における `{...}` は特殊な記法です。
明示していない引数が外部から渡されても許容する、という意味です。
これを書いていない場合、引数として定義していない変数が渡されるとエラーが発生します。
暗黙的な記法なので私は好みませんが、実運用上、書いておくと便利です。
先述の通り、ツール（関数）によっては暗黙的に引数を渡してくる仕様のものがあります。

:::


### 3.3.2 コミット位置の確認
現在の世代がどのリビジョンから構築したか、以下のコマンドで確認できます。

```zsh:Zsh
darwin-version --configuration-revision
```

:::message
なお、`--json` オプションを利用すると、より多くの情報が確認できます。

```zsh:Zsh
> darwin-version --json                  
{
  "configurationRevision": "74dd96960fa1be335e96a8790d034f58e6b9ecb8",
  "darwinLabel": "26.05.9f48ffa",
  "darwinRevision": "9f48ffaca1f44b3e590976b4da8666a9e86e6eb1",
  "nixpkgsRevision": "a82ccc39b39b621151d6732718e3e250109076fa"
}
```

:::


# 4. 後方互換性（stateVersion）
`system.stateVersion` は後方互換性を確保するための設定です。

執筆時点（2026/2）では 6 が最新です。

```nix:~/work/dotfiles/configuration.nix
{
  # ...
  system.stateVersion = 6;
}
```

インストールした時期に依存するので、公式リファレンスにて Default 値を確認してください。

https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-system.stateVersion

:::message
値が 7 以上になっていた場合（本書のサンプルコードが古い状態になっていた場合）、リファレンス記載の値に書き換えてください。
:::


**nix-darwin を使い始めてからは、原則、この値を変更しないでください**。

もし nix-darwin をアップデートした場合、以下のコマンドでリリースノートを表示し、`stateVersion` の変更指示があるかを確認します。

破壊的変更がある場合は `stateVersion` が変わるかと思います。
自身の環境に悪影響を及ばさないと判断できる場合、または、壊れても対処する時間的余裕がある場合のみ、指示に従って値を変更してください。


```zsh:Zsh
darwin-rebuild changelog
```

```zsh:Zsh
> darwin-rebuild changelog
# ...

2025-01-18
- The default configuration path for all new installations
  is `/etc/nix-darwin`. This was already the undocumented
  default for `darwin-rebuild switch` when using flakes. This
  is implemented by setting `environment.darwinConfig` to
  `"/etc/nix-darwin/configuration.nix"` by default when
  `system.stateVersion` ≥ 6.

# ...
```


# 5. 本体の更新
`flake.nix` があるディレクトリにて以下を実行します。

```zsh:Zsh
nix flake update nix-darwin
```

ロックフィルが更新されます。
その後、`switch` すると nix-darwin 本体が更新されます。

```zsh:Zsh
sudo darwin-rebuild switch 
```
