---
title: "nix-darwin で Mac のシステム設定を管理する"
---

# 1. この章でやること
この章では、nix-darwin で **Mac のシステム設定を宣言的に管理する**例を紹介します。


# 2. カスタマイズの進め方
nix-darwin は多種多様な設定が可能です。
時間に余裕がある場合、nix-darwin のリファレンスを流し読みすると色々な設定が知れるので面白いと思います。

https://nix-darwin.github.io/nix-darwin/manual/

とはいえ、最初は設定項目が多すぎて何から手をつけるべきか分からなくなります。
まずは他者の設定（dotfiles）を真似つつ、自分の好みにカスタマイズしていくとスムーズだと思います。

以降では、私が利用している設定を紹介します。

:::message
これまでの章を実施済み = home-manager と homebrew を nix-darwin で管理している前提です。

これらを nix-darwin で管理していない場合、`homebrew.nix` と `home_manager.nix` の解説部分を無視してください。
それ以外の箇所は Mac 本体の設定なので、参考にできるはずです。
:::


# 3. 全体の構成
参考までに、私の構成例を示します。

```:フォルダ構成
~/work/dotfiles/
├── flake.nix
├── flake.lock
├── home.nix # home-manager 設定
├── nix-darwin/
│    ├── configuration.nix # 基本設定
│    ├── nixpkgs.nix # nixpkgs 設定
│    ├── home_manager.nix # home-manager module 設定
│    ├── homebrew.nix # homebrew 設定
│    └── system.nix # 本体設定
└── ... # git/.gitconfig 等
```

```nix:flake.nix
{
  description = "nix-darwin configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    {
      darwinConfigurations."MacBook" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit self; };
        modules = [
          ./nix-darwin/configuration.nix
          home-manager.darwinModules.home-manager
        ];
      };
    };
}
```

:::message
本章の解説では、ホスト名 `MacBook`、ユーザ名 `ryu`、システム `aarch64-darwin` として記述しています。
各自の環境に合わせて値を置き換えてください。
:::


# 4. 基本の設定
`configuration.nix` にて、nix-darwin の基本的な設定、および、各設定の読み込みを定義しています。

```nix:configuration.nix
{
  pkgs,
  self,
  ...
}:
{
  system = {
    # 後方互換性のための値、nix-darwin 本体のバージョン依存
    # 原則、各自がインストールした際に設定した値のままにしてください
    stateVersion = 6;

    # ビルド時の設定ファイルのコミット位置を記録
    configurationRevision = self.rev or self.dirtyRev or null;

    # Mac 本体のユーザー設定を変更する際に必要
    primaryUser = "ryu";
  };

  # ホームディレクトリを指定
  users.users.ryu.home = "/Users/ryu";

  # Determinate-Nix を利用している場合、必須
  nix.enable = false;

  # 利用するシェルを指定する
  programs.zsh.enable = true;
  # programs.fish.enable = true;

  # 各種設定をロード
  imports = [
    ./nixpkgs.nix
    ./home_manager.nix
    ./homebrew.nix
    ./system.nix
  ];
}
```

# 5. home-manager の設定
`home_manager.nix` にて、home-manager の設定を定義しています。

```nix:home_manager.nix
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."ryu" = {
    imports = [
      ../home.nix
    ];
  };
}
```


# 6. Homebrew の設定
`homebrew.nix` にて、Homebrew の設定を定義しています。

```nix:homebrew.nix
{
  homebrew = {
    enable = true;
    user = "ryu";
    onActivation = {
      cleanup = "uninstall";
      upgrade = true;
      autoUpdate = false;
    };
    global.autoUpdate = false;
    brews = [
    ];
    casks = [
      "linearmouse"
      "elecom-mouse-util"
    ];
  };
}
```


# 7. Mac 本体の設定
`system.nix` にて、Mac 本体の設定を定義しています。

メジャーな設定は nix-darwin の設定が用意されています。

例えば、`defaults write com.apple.dock show-recents -bool false` を nix-darwin で設定したい場合、`show-recents` で nix-darwin リファレンスを単語検索します。
すると、`system.defaults.dock.show-recents` がヒットしますので、以下のように設定可能と分かります。

```nix
system.defaults.dock.show-recents = false
```

一方、単語検索してもヒットしない場合、`system.defaults.CustomUserPreferences` を利用して設定を記述します。

```nix
# CLI での設定コマンド
# defaults write -g "WebAutomaticSpellingCorrectionEnabled" -bool false

# nix-darwin の記述に置き換え
system.defaults.CustomUserPreferences = {
  NSGlobalDomain.WebAutomaticSpellingCorrectionEnabled = false;
};
```

以下は、ネット検索で出てくる Mac 購入後おすすめ設定集を nix-darwin で書いています。

```nix:homebrew.nix
{
  pkgs,
  ...
}:
{
  system.defaults = {
    NSGlobalDomain = {
      # マウス/トラックパッド
      "com.apple.swipescrolldirection" = true; # ナチュラルスクロールを有効化
      # キーボード
      NSAutomaticCapitalizationEnabled = false; # 文頭の自動大文字化を無効化
      NSAutomaticPeriodSubstitutionEnabled = false; # ピリオドの自動置換を無効化
      NSAutomaticSpellingCorrectionEnabled = false; # スペル自動修正を無効化
      NSAutomaticDashSubstitutionEnabled = false; # ダッシュの自動置換を無効化
      NSAutomaticQuoteSubstitutionEnabled = false; # クォートの自動置
      # UI
      AppleInterfaceStyle = "Dark"; # ダークモードを有効化
      NSWindowResizeTime = 0.001; # ウィンドウのリサイズ速度を高速化
    };
    # Finder
    finder = {
      AppleShowAllExtensions = true; # ファイル拡張子を常に表示
      AppleShowAllFiles = true; # 隠しファイルを表示
      FXDefaultSearchScope = "SCcf"; # 検索範囲をカレントフォルダに設定
      ShowPathbar = true; # パスバーを表示
      FXEnableExtensionChangeWarning = false; # ファイル拡張子変更の警告を無効化
      FXPreferredViewStyle = "Nlsv"; # デフォルトの表示方法をリストビューに設定
    };
    # Dock
    dock = {
      show-process-indicators = true; # 起動中アプリをインジケーターに表示
      show-recents = false; # 最近使ったアプリを非表示
      launchanim = false; # アプリ起動時のアニメーションを無効化
      mineffect = "scale"; # ウィンドウを閉じるときのエフェクトをスケールに設定
    };
    # 画面キャプチャ
    screencapture = {
      target = "clipboard"; # スクリーンショットの保存先をクリップボードに設定
      disable-shadow = true; # スクリーンショットの影を無効化
    };
    # その他
    CustomUserPreferences = {
      NSGlobalDomain = {
        # キーボード
        WebAutomaticSpellingCorrectionEnabled = false; # スペル自動修正を無効化 (WebView)
        # Finder
        AppleMenuBarVisibleInFullscreen = true; # フルスクリーン時にメニューバーを表示
      };
    };
  };

  # 電源設定
  power = {
    sleep = {
      allowSleepByPowerButton = false; # 電源ボタンでスリープを無効化
      computer = 60; # 自動スリープまでの時間（分）
      display = 60; # ディスプレイの自動スリープまでの時間（分）
    };
  };
}
```

また、nix-darwin ではキーマッピングを変更することも可能です。
詳細は以下の記事を参照ください。

https://zenn.dev/trifolium/articles/a6fc32a05be6d0

```nix:homebrew.nix
{
  pkgs,
  ...
}:
{
  # キーマッピング
  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping =
      let
        mkKeyMapping =
          let
            hexToInt = s: pkgs.lib.trivial.fromHexString s;
          in
          src: dst: {
            HIDKeyboardModifierMappingSrc = hexToInt src;
            HIDKeyboardModifierMappingDst = hexToInt dst;
          };
        # Key-map References:
        #   https://developer.apple.com/library/archive/technotes/tn2450/_index.html
        # e.g.
        #   07000 = Keyboard, 000E0 = Keyboard Left Control
        #     -> 0x7000000E3 = Keyboard Left Command
        # macOS Fn key:
        #   https://apple.stackexchange.com/questions/340607/what-is-the-hex-id-for-fn-key%EF%BC%89
        leftControl = "0x7000000E0";
        leftCommand = "0x7000000E3";
        capsLock = "0x700000039";
        fnKey = "0xFF00000003";
      in
      [
        # Left Control <-> GUI(Command)
        (mkKeyMapping leftControl leftCommand)
        (mkKeyMapping leftCommand leftControl)
        # Caps Lock -> Fn
        (mkKeyMapping capsLock fnKey)
      ];
  };
}
```
