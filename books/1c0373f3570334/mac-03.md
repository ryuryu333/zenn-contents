---
title: "nix-darwin の基本的な使い方"
---

# 1. この章でやること
この章では **nix-darwin の基本的な使い方**を解説します。
また、推奨されている基本的な設定について解説します。

:::message
操作例として 1 つだけ Mac のシステム設定を変更します。

より詳しいシステム設定方法については個別の章で解説します。
また、home-manager や Homebrew の管理についても次章以降にて扱います。
:::


# 2. 最小構成で動かす
## 2.1 設定ファイルを編集する
本セクションでは、sudo コマンドの認証に Touch ID を利用できるように設定します。
`security.pam.services.sudo_local.touchIdAuth = true;` を `flake.nix` に追記します。

```nix:~/work/dotfiles/flake.nix
{
  description = "nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, nix-darwin, ... }:
    {
      darwinConfigurations."<hostname>" = nix-darwin.lib.darwinSystem {
        modules = [
          {
            nixpkgs.hostPlatform = "<platform>";
            system.stateVersion = 6;
            nix.enable = false;
            security.pam.services.sudo_local.touchIdAuth = true;
          }
        ];
      };
    };
}
```

## 2.2 反映する
`flake.nix` を配置しているディレクトリ（`~/work/dotfiles`）にて以下を実行します。

```bash:Bash
sudo darwin-rebuild switch --flake .
```


# 3. flake.nix の配置場所
`darwin-rebuild switch` コマンドは `/etc/nix-darwin/flake.nix` を探します。
前章では `~/work/dotfiles` に `flake.nix` を作成したので、`switch --flake .` オプションを付ける必要があります。

任意の設定ですが、私はコマンドを簡略化したいので、`/etc/nix-darwin/` にシンボリックリンクを作成しています。

```bash:Bash
sudo ln -s /Users/ryu/work/dotfiles/flake.nix /etc/nix-darwin/flake.nix
```

:::message
以降は `/etc/nix-darwin/flake.nix` がある前提でコマンドを提示します。
シンボリックリンクを作成しない場合は、`sudo darwin-rebuild switch` コマンドに `switch --flake .` をつけてください。
:::


# 4. 設定ファイルの分離
これまでのコード例では `flake.nix` の `modules = []` に設定を記述していました。

```nix:~/work/dotfiles/flake.nix
modules = [
  {
    nixpkgs.hostPlatform = "<platform>";
    system.stateVersion = 6;
    nix.enable = false;
    security.pam.services.sudo_local.touchIdAuth = true;
  }
]
```

nix-darwin の設定が増えてくると可読性が落ち、管理が手間になります。
そこで、`configuration.nix` として分離します。

>ファイル名は任意です。

```nix:~/work/dotfiles/configuration.nix
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  nix.enable = false;
}
```

`flake.nix` にて `modules` のリストに `configuration.nix` を渡します。

```nix:~/work/dotfiles/flake.nix
{
  description = "nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, nix-darwin, ... }:
    {
      darwinConfigurations."<hostname>" = nix-darwin.lib.darwinSystem {
        modules = [
          ./configuration.nix
        ];
      };
    };
}
```


:::message
`configuration.nix` が慣習的に使われることが多いですが、ファイル名は任意です。
設定が増えた場合、複数の `~.nix` に分割すると管理が楽かと思います。
:::


# 5. システム設定のバージョン管理
## 5.1 世代の確認
以下のコマンドで世代一覧を確認できます。
古いものから順に表示されるため、`tail` で最近の世代だけ表示させています。

```bash:Bash
sudo darwin-rebuild --list-generations | tail -n 5
```

```bash:Bash
$ sudo darwin-rebuild --list-generations | tail -n 5
  1    yyyy-mm-dd hh:mm:ss   
  2    yyyy-mm-dd hh:mm:ss   
  3    yyyy-mm-dd hh:mm:ss   
  4    yyyy-mm-dd hh:mm:ss   
  5    yyyy-mm-dd hh:mm:ss   (current)
```


## 5.2 ロールバック
1 つ前の世代に戻りたい場合、以下を実行します。

```bash:Bash
sudo darwin-rebuild --rollback
```

特定の世代も指定できます。

```bash:Bash
sudo darwin-rebuild --switch-generation <generation>
```

```bash:Bash
$ sudo darwin-rebuild --rollback

$ sudo darwin-rebuild --list-generations | tail -n 5
  1    yyyy-mm-dd hh:mm:ss   
  2    yyyy-mm-dd hh:mm:ss   
  3    yyyy-mm-dd hh:mm:ss   
  4    yyyy-mm-dd hh:mm:ss   (current)
  5    yyyy-mm-dd hh:mm:ss   

$ sudo darwin-rebuild --switch-generation 3

$ sudo darwin-rebuild --list-generations | tail -n 5
  1    yyyy-mm-dd hh:mm:ss   
  2    yyyy-mm-dd hh:mm:ss   
  3    yyyy-mm-dd hh:mm:ss   (current)
  4    yyyy-mm-dd hh:mm:ss   
  5    yyyy-mm-dd hh:mm:ss   
```


## 5.3 システム構築情報（ハッシュ値）の管理
### 5.3.1 configurationRevision の設定
nix-darwin には、現在のシステムがどの Git コミットの `flake.nix` から構築されたかを記録する仕組みがあります。

>`flake.nix` を Git 管理している前提です。

環境が壊れた際、どこの変更が原因であったかの調査等に有用かと思うので、設定に加えます。
`configuration.nix` を以下のように編集します。

```nix:~/work/dotfiles/configuration.nix
{
  self,
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  nix.enable = false;
  system.configurationRevision = self.rev or self.dirtyRev or null;
}
```

`flake.nix` は以下のように記述します。

```nix:~/work/dotfiles/flake.nix
{
  description = "nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nix-darwin, ... }:
    {
      darwinConfigurations."<hostname>" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit self; };
        modules = [
          ./configuration.nix
        ];
      };
    };
}
```


:::details コードの解説（難しかったら読み飛ばしてください）
これまでのサンプルコードと見た目が大きく変わったと思うので、補足します。

まず、解説のために `configurationRevision` をシンプルに記述します。

`configurationRevision` の他に、`outputs = {}` にて `self` が追記されていることに注目してください。

```nix:~/work/dotfiles/flake.nix
  outputs =
    { self, nixpkgs, nix-darwin, ... }:
    {
      darwinConfigurations."<hostname>" = nix-darwin.lib.darwinSystem {
        modules = [
          {
            nixpkgs.hostPlatform = "<platform>";
            system.stateVersion = 6;
            nix.enable = false;
            system.configurationRevision = self.rev or self.dirtyRev or null;
          }
        ];
      };
    };
```

`self` は `flake.nix` 自身を意味します。
`rev` は Git のリビジョン（どのコミット位置か）を意味します。

`self.rev` で `flake.nix` のコミット位置（ハッシュ値）を取得できます。

>`self.rev` は Clean（全てコミット済み）な状態が前提なので、未コミット時は `self.dirtyRev` からハッシュ値を取得します。

---

`configurationRevision` にて `self` を利用するため、`outputs = {}` にて `self` を記述しています。

>この outputs の書き方は Flakes 特有ですので、こう書くもの、と理解してください（解説すると複雑になるので）。

---

次は、この設定を `configuration.nix` に分離します。

```nix:~/work/dotfiles/configuration.nix
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  nix.enable = false;
  system.configurationRevision = self.rev or self.dirtyRev or null;
}
```

このままだと、`error: attribute 'self' missing` となります。

そのため、`flake.nix` から `self` を `configuration.nix` に渡す必要があります。
以下のように `specialArgs` を利用します。

```nix:~/work/dotfiles/flake.nix
  outputs = 
    { self, nixpkgs, nix-darwin, ... }:
    {
      darwinConfigurations."MacBook" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit self; };
        modules = [
          ./configuration.nix
        ];
      };
    };
```

>`inherit self` は `self = self` と同義です。
より書き下すと、`specialArgs.self = self` となります。
これは、specialArgs の self として、既存の変数である self を代入しています。

次に、`configuration.nix` にて `self` を受け取る準備をします。

```nix:~/work/dotfiles/configuration.nix
{
  self,
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  nix.enable = false;
  system.configurationRevision = self.rev or self.dirtyRev or null;
}
```

これは、引数として `self` を受け取るという意味になります。

>Nix 言語において、`{}:{}`（<引数>:<式>）で関数を定義できます。
`modules` のリストとして `~.nix` を指定すると、`specialArgs` で指定した変数が渡されます。

>nix-darwin では、`lib`、`config`、`pkgs` はデフォルトで `modules` に指定した `~.nix` へ渡されます。
`self` は対象外なので、`specialArgs` を利用して明示的に渡す必要があります。

結果、`self.rev` を評価すると `flake.nix` のコミットハッシュとなり、それを `configurationRevision` に代入できるようになりました。
:::

### 5.3.2 ハッシュ値の確認
現在の世代がどの `flake.nix` から構築したか、以下のコマンドで確認できます。

```bash:Bash
darwin-version --configuration-revision
```

出力された値は現在の `flake.nix` のコミットハッシュ値になっているはずです。


# 6. stateVersion
`system.stateVersion` は後方互換性を確保するための設定です。

執筆時点では 6 が最新であり、最新の nix-darwin をインストールしているので 6 を指定しています。

```nix:~/work/dotfiles/configuration.nix
{
  # ...
  system.stateVersion = 6;
}
```

インストールした時期に依存するので、公式リファレンスを確認し、必要に応じて変更してください。

https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-system.stateVersion

nix-darwin をアップデートした際、この値は原則変えません。

まず、以下のコマンドでリリースノートを表示し、`stateVersion` の変更指示があるかを確認します。
更新内容が自身の環境に悪影響を及ばさないと判断した後、指示に従って値を変更してください。

```bash:Bash
darwin-rebuild changelog
```

```bash:Bash
$ darwin-rebuild changelog
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
