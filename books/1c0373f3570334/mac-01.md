---
title: "第三部 システム環境の管理（Mac 限定）"
---

第三部では、nix-darwin で Mac のシステム環境を管理する方法を解説します。

Nix は本来パッケージマネージャーですが、これを **Mac のシステム設定の管理に応用したツールが nix-darwin** です。

https://github.com/nix-darwin/nix-darwin

GUI の設定画面や `defaults write` コマンドで行うシステム設定をテキストで宣言的に管理できます。

```nix:設定例
system.defaults = {
  finder = {
    AppleShowAllExtensions = true; # ファイル拡張子を常に表示
    AppleShowAllFiles = true; # 隠しファイルを表示
  };
};
```

----

また、nix-darwin は Home Manager や Homebrew も管理できます。
そのため、ユーザー環境とシステム環境を一括管理できるようになります。

----

次章からは nix-darwin でシステム環境を管理する方法を解説していきます。

:::message
**Home Manager を導入していること（第二部済み）が前提となります**。

厳密には、Home Manager は無くとも問題ありませんが、システム領域を nix-darwin、ユーザー環境を Home Manager と責務を分割すると管理が楽です。
:::


# 目次

1. nix-darwin のインストール
2. nix-darwin の基本的な使い方
3. nix-darwin で Home Manager を管理する
4. nix-darwin で Homebrew を管理する
5. nix-darwin で Mac のシステム設定を管理する
