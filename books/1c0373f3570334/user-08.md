---
title: "2.7 Home Manager と Homebrew の共存"
---

# 1. この章でやること
この章では、Home Manager と Homebrew を併用した際、どのような挙動となるのか、共存は可能であるのかを解説します。

:::message
Homebrew に特化した解説となりますが、他のパッケージマネージャーも同様に併用できるかと思います。
:::

本章を読んだ後、こちらも読み返すと理解しやすいかと思います。

https://zenn.dev/trifolium/books/1c0373f3570334/viewer/common-04


# 2. Homebrew と競合するのか？
**同じパッケージが入っていても問題ありません**。  
実際に使われるのは **PATH の先にある方**です。

確認したい場合は `which` / `which -a` でどちらが使われているか分かります。

:::message
例えば、Home Manager で nixfmt を入れた場合、以下のように表示されます。

```zsh:Zsh
$ which nixfmt
/Users/ryu/.nix-profile/bin/nixfmt

$ which -a nixfmt
/Users/ryu/.nix-profile/bin/nixfmt
```

>Users/ryu の部分は自身の環境のユーザー名になります。

:::


# 3. Homebrew と Home Manager で同じパッケージを入れた場合
敢えて、nixfmt を Homebrew でインストールしてみます。

```zsh:Zsh
> brew install nixfmt

> brew list | grep nixfmt
nixfmt
```

この状態で `which` / `which -a` を確認します。

```zsh:Zsh
> which nixfmt
/Users/ryu/.nix-profile/bin/nixfmt

> which -a nixfmt
/opt/homebrew/bin/nixfmt
/Users/ryu/.nix-profile/bin/nixfmt
```

このように、**Home Manager と Homebrew で管理された nixfmt が共存しています**。

`home-manager switch` を行うと、Nix 管理下の nixfmt が環境変数 `PATH` の先頭寄りに登録されます。
そのため、**Homebrew ではなく Home Manager の nixfmt が優先して呼ばれる状態**になります。

:::message
Home Manager の設定から nixfmt を除外すれば、Homebrew の nixfmt が実行できる状態になります。
:::


# 4. 依存ライブラリの扱い
nixfmt に紐づけられている shared libraries を otool で確認します。

**Homebrew 側では `/usr/lib/~`、Home Manager 側では `nix/store/~` となっていることに注目してください**。

<!-- cspell:disable -->

```zsh:Zsh
$ otool -L /opt/homebrew/bin/nixfmt
/opt/homebrew/bin/nixfmt:
        /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1351.0.0)
        /usr/lib/libiconv.2.dylib (compatibility version 7.0.0, current version 7.0.0)
        /opt/homebrew/opt/gmp/lib/libgmp.10.dylib (compatibility version 16.0.0, current version 16.0.0)
        /usr/lib/libffi.dylib (compatibility version 1.0.0, current version 40.0.0)
        /usr/lib/libcharset.1.dylib (compatibility version 1.0.0, current version 1.0.0)
```

```zsh:Zsh
$ otool -L /Users/ryu/.nix-profile/bin/nixfmt
/Users/ryu/.nix-profile/bin/nixfmt:
        /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.100.2)
        /nix/store/6nmmi317rg2bnybndbgc944dpg5cnl5a-libiconv-109.100.2/lib/libiconv.2.dylib (compatibility version 7.0.0, current version 7.0.0)
        /nix/store/c3pfhyhy0hyhff79slz8js78gv2zrg27-gmp-with-cxx-6.3.0/lib/libgmp.10.dylib (compatibility version 16.0.0, current version 16.0.0)
        /nix/store/n8ylivq3rz4dai1yfrf71xqc2fyvwrcn-libffi-40/lib/libffi.7.dylib (compatibility version 9.0.0, current version 9.0.0)
```

<!-- cspell:enable -->

:::message
`/usr/lib/libSystem.B.dylib` は Nix 管理外じゃないか！と思うかもしれませんが、これは仕様です。
libSystem は macOS に強く紐づいているので例外的な処置となっています。

参考資料: [リンク](https://daiderd.com/2020/06/25/nix-and-libsystem.html)

このような例外を除き、**Nix は依存を含めてビルドします**。
そして、これら**依存ライブラリのバージョンはロックファイルで固定**されます。
:::

:::message
仮に、別のソフトで nixfmt と同じライブラリを必要となり、かつ、違うバージョンが要求された場合、バージョン毎に `nix/store/hash-name-version` が作成されます。

同じライブラリをバージョン毎に用意するので、**ソフト A をインストールしたらソフト B の依存ライブラリが変更された、という状況を防げます**。

これは Nix の大きな魅力だと思います。
:::
