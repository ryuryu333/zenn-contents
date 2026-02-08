---
title: "nix-darwin で Homebrew を管理する"
---

# 1. この章でやること
この章では、**nix-darwin で Homebrew を管理し、ツールをインストール・更新する方法**を解説します。

:::message
すでに Homebrew がインストールされている前提の解説です。
本書の構成では、nix-darwin は Homebrew 本体をインストールしません。
未インストールの場合は、[公式サイト](https://brew.sh/ja/)に従って導入してください。
:::

:::details Homebrew 本体も nix-darwin で管理したい場合
[nix-homebrew](https://github.com/zhaofengli/nix-homebrew) を nix-darwin のモジュールとして利用すると、Homebrew 本体のインストールも可能になります。
本書では扱いません。
:::


# 2. homebrew を有効化する
`configuration.nix` に homebrew の設定を追加します。

`<username>` は自身のユーザ名に置き換えてください。

```nix:~/work/dotfiles/configuration.nix
{
  homebrew = {
    enable = true;
    user = "<username>";
    brews = [
    ];
    casks = [
    ];
    taps = [
    ];
  };
}
```


# 3. ツールを追加する
`brews` は CLI ツール、`casks` は GUI アプリを指定します。
必要なツールを配列に追加していきます。

また、サードパーティ formula の追加（`brew tap`）も可能です。

```nix:~/work/dotfiles/configuration.nix
  homebrew = {
    enable = true;
    user = "<username>";
    brews = [
      # brew install nginx
      "nginx"
      # brew install petere/postgresql/postgresql-common
      "petere/postgresql/postgresql-common"
    ];
    casks = [
      # brew install --cask microsoft-office
      "microsoft-office"
    ];
    
    taps = [
      # brew tap petere/postgresql
      "petere/postgresql"
      
      # URL を指定する書き方も可能（架空の URL なのでコメントアウト）
      # brew tap user/tap-repo https://user@bitbucket.org/user/homebrew-tap-repo.git
      # {
      #   name = "user/tap-repo";
      #   clone_target = "https://user@bitbucket.org/user/homebrew-tap-repo.git";
      # }
    ];

  };
```


# 4. 反映する
nix-darwin の環境を更新すると、Homebrew によるツールのインストール処理も実施されます。

```bash:Bash
sudo darwin-rebuild switch
```


# 5. 既存の Homebrew からツールを移行する
Homebrew で手動インストールした CLI ツールは `--installed-on-request` で抽出できます。
`brew list` だと依存関係で自動インストールされたツールも混ざるため、移行対象の整理には不向きです。

GUI ツールは `brew list --cask` で一覧化できます。

```bash:Bash
brew list --installed-on-request
```

```bash:Bash
brew list --cask
```

表示されたツールを `brews` / `casks` に追加し、`sudo darwin-rebuild switch` で反映します。


# 6. その他の設定
## 6.1 ツールの更新設定
Homebrew 本体や管理下のツールの更新タイミングを設定できます。

デフォルト設定だと、`brew upgrade` コマンドを手動実行した場合に更新されます。
`sudo darwin-rebuild switch` した際、ツールのインストールは行われますが、更新処理はされないので注意してください。

:::message
`sudo darwin-rebuild switch` 実行時、一時的に `HOMEBREW_NO_AUTO_UPDATE = 1` が設定された状態で、`brew bundle install --no-upgrade` が実行されます。
:::

なお、デフォルト設定では、手動で `brew` コマンド（`brew install`、`brew tap` 等）を実行した場合に自動更新が走ります。
そのため、意図せず更新してしまう可能性があります。

以下の設定を行うと、Nix（`flake.nix`）に近い運用が可能になります。

```nix:~/work/dotfiles/configuration.nix
  homebrew = {
    onActivation = {
      upgrade = true;  // デフォルト false
      autoUpdate = false;  // デフォルト false
    };
    global.autoUpdate = false;  // デフォルト true
  };
```

この設定では、`HOMEBREW_NO_AUTO_UPDATE=1` が環境変数としてセットされるため、手動で `brew` コマンドを実行しても自動更新されません。

明示的に `brew update` して formula（パッケージ定義）を更新した後、`sudo darwin-rebuild switch` することで、ツールが最新バージョンに更新されます。

:::message
`nix flake update` して `flake.lock` を更新した後、環境を更新するとツールが更新される、という流れと似た運用になります。

いつ更新するかが明確になり、かつ、コマンドの責務が分離できる（`brew update` がパッケージ定義の更新、`sudo darwin-rebuild switch` が定義に基づいたツールのインストール・更新）ので、個人的に好きな設定です。
:::


## 6.2 homebrew.onActivation.cleanup
`uninstall` を指定すると、リストに記載していないツールは自動的にアンインストールされます。

デフォルト設定（`none`）の場合、リストから除外してもアンインストールされません。

:::message
`sudo darwin-rebuild switch` した際、`brew bundle install --cleanup` コマンドが実行されます。
設定ファイル（`configuration.nix` 等）で宣言されていない（＝手動でインストールしたツール）はアンインストールされるので、注意してください。

既存の Homebrew で入れたツールを nix-darwin 側に全て移してから、設定してください。
:::

```nix:~/work/dotfiles/configuration.nix
  homebrew = {
    onActivation.cleanup = "uninstall";
  };
```


# 7. 最終的な設定例・運用例

```nix:~/work/dotfiles/configuration.nix
  homebrew = {
    enable = true;
    user = "<username>";

    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = true;
      # cleanup = "uninstall";  # Homebrew からの移行完了後に設定
    };

    brews = [
      # brew install nginx
      "nginx"
    ];
    casks = [
      # brew install --cask microsoft-office
      "microsoft-office"
    ];
  };
```

ツールを追加・除外する場合は、brews と casks のリストを編集した後、nix-darwin の環境を更新します。

```bash:Bash
sudo darwin-rebuild switch
```

Homebrew 本体・ツールを更新する場合は、以下のコマンドを順に実行します。

```bash:Bash
brew update
sudo darwin-rebuild switch
```

:::message
上記操作は、home-manager 管理下のツールを更新する場合と似た流れです。

```bash:Bash
nix flake update
sudo darwin-rebuild switch
```

更新操作が煩雑だと思った場合は、[go-task](https://github.com/go-task/task) 等のタスクランナーツールや `flake.nix` の `apps`（Nix Flakes のタスクランナー的な機能）を用いて、各種コマンドを一括実行するタスクを作ると楽です。

`flake.nix` の `apps` については本書後半の章で解説しますので、ご参照ください。
:::
