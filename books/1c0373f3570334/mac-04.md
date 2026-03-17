---
title: "3.3 nix-darwin で Mac のシステム設定を管理する"
---

# 1. この章でやること
この章では、nix-darwin で Mac のシステム設定を宣言的に管理する例を紹介します。


# 2. カスタマイズの進め方
nix-darwin は多種多様な設定が可能です。
時間に余裕がある場合、nix-darwin のリファレンスを流し読みすると色々な設定が知れるので面白いと思います。

https://nix-darwin.github.io/nix-darwin/manual/

とはいえ、最初は設定項目が多すぎて何から手をつけるべきか分からなくなります。
まずは他者の設定（dotfiles）を真似つつ、自分の好みにカスタマイズしていくとスムーズだと思います。

以降では、私が利用している設定を紹介します。

:::message
本章の解説では、ホスト名 `MacBook`、ユーザ名 `ryu`、システム `aarch64-darwin` として記述しています。
各自の環境に合わせて値を置き換えてください。
:::


# 3. 基本的の設定
nix-darwin の基本的な設定を記述していきます。

```nix:configuration.nix
{
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

  # nix-darwin による Nix 管理を無効化  
  nix.enable = false;

  # 利用するシェルを指定する
  programs.zsh.enable = true;
  # programs.fish.enable = true;  # 他のシェルの場合
}
```


# 4. システム設定の探し方
メジャーな設定は nix-darwin に設定が用意されています。

例えば、Dock に最近使ったアプリアイコンを表示しない設定にする場合を考えてみます。
通常では、システム設定の GUI から変更するか、以下のコマンドを実行します。

```zsh:Zsh
defaults write com.apple.dock show-recents -bool false
```

**nix-darwin で設定したい場合、`show-recents` で [nix-darwin リファレンス](https://nix-darwin.github.io/nix-darwin/manual/)を単語検索します**。
すると、`system.defaults.dock.show-recents` がヒットしますので、以下のように設定可能と分かります。

```nix
system.defaults.dock.show-recents = false
```

このように、**nix-darwin の設定項目は `defaults` コマンドに似た名前が付けられていることが多いです**。


# 5. nix-darwin に用意されていない設定の場合
nix-darwin のリファレンスで見つからない設定を記述したい場合、`system.defaults.CustomUserPreferences` を利用します。

**`defaults` コマンドでの設定方法を調べ、コマンドの記述を `system.defaults.CustomUserPreferences` に書き換えるイメージです**。

```zsh:CLI での設定コマンド
defaults write -g "WebAutomaticSpellingCorrectionEnabled" -bool false
```

```nix:nix-darwin の記述に置き換え
system.defaults.CustomUserPreferences = {
  NSGlobalDomain.WebAutomaticSpellingCorrectionEnabled = false;
};
```


# 6. Mac システム設定例
以下はネット検索で出てくる Mac 購入後おすすめ設定集を参考にして、nix-darwin に落とし込んだ例です。


<!-- cspell:disable -->

```nix:configuration.nix
{
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

<!-- cspell:enable -->



また、nix-darwin ではキーマッピングを変更できます。
詳細は以下の記事を参照ください。

https://zenn.dev/trifolium/articles/a6fc32a05be6d0

```nix:configuration.nix
{
  lib,
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
            hexToInt = lib.trivial.fromHexString;
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


# 7. 設定の管理
上記の通り、`configuration.nix` に記載する内容は長くなりがちです。

Home Manager と同様に、設定ファイルを分割すると楽です。

```:分割例
nix-darwin/
├── configuration.nix
├── home_manager.nix
├── homebrew.nix
├── nixpkgs.nix
└── system.nix
```

>次章以降で扱う内容ですが、Home Manager や Homebrew の設定用の記述も単独のファイルで管理しています。

他の方々と比べると簡素ですが、私の dotfiles は以下で公開しています。
ご参考までに。

https://github.com/ryuryu333/dotfiles
