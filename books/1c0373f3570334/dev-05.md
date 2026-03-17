---
title: "4.4 devShell 以外の方法での開発環境管理"
---

# 1. この章でやること
この章では `flake.nix` で devShell を直接記述する以外の方法を紹介します。


:::message
筆者は `flake.nix` を直接書いた方が楽だと思っています。
一方、人によっては Nix をラップして JSON などで設定を記述できた方が楽と感じるかもしれません。

**本章は「こんなツールもあるんだ」という視点でお読みください、詳細な使用方法までは解説しません**。

----

ちなみに、筆者はどのツールも触ったことがあります。
**しかし、ツールの独自ルールを覚えるのが難しい（自分好みにカスタマイズするのが大変）と感じ、結局 `flake.nix` を雑に書いた方が楽、という状態になっています...**。

**どれも良いツールなのですが、`flake.nix` の方が実装（ソースコード）を調査する難易度が低いのです**。
高度にラップされたツール独自関数を駆使するよりも、Nix 言語で関数を自作したリ、Nixpkgs のライブラリを直接使う方が思い通りの挙動をそのまま記述できるので楽だと感じています。

----

もしかしたら、Nix でパッケージ管理以外（環境変数管理、サービスの管理（PostgreSQL の起動など）、タスクランナー、リンター・フォーマッター、テスト、ビルド）を行いたい場合は、`flake.nix` よりも各種ツールの方が楽になるのかもしれません。

>筆者は緩く Nix を使っているので、パッケージ管理以外はその他のツール（タスクなら go-task など）に責務を分散させがちです。

:::

シンプルなツールから順に紹介します。


# 2. LazyNix
[LazyNix](https://github.com/shunsock/lazynix) は YAML で開発環境の設定を記述します。
**機能はシンプルよりで `flake.nix` のラッパーといった立ち位置です**。

独自の設定ファイル（`lazynix.yaml`）から `flake.nix` を自動生成し、devShell 環境を起動します。


:::message
**最初は LazyNix でシンプルに運用して、LazyNix で実現が難しいカスタマイズをしたくなったら `flake.nix` を直接利用するスタイルに移行、といったことが可能かと思います**。
:::


<!-- cspell:disable -->

```yaml:lazynix.yaml
devShell:
  allowUnfree: false

  package:
    stable:
      - python312
      - uv
    unstable: []

  shellHook:
    - "echo Python $(python --version) ready!"
    - "echo uv $(uv --version) ready!"

  env:
    # Load from .env files
    dotenv:
      - .env

    # Define variables directly
    envvar:
      - name: PYTHONPATH
        value: ./src
      - name: DEBUG
        value: "true"
```

<!-- cspell:enable -->


# 3. Devbox
[Devbox](https://github.com/jetify-com/devbox) は JSON で開発環境の設定を記述します。
**内部では Nix を用いていますが、ユーザーが Nix 言語を記述しなくてもよいのが利点と言えるでしょう**。

[mise](https://mise.jdx.dev/) などに近い使用感かと思います。

```zsh:Zsh
devbox init
devbox add python@3.12
devbox shell
```

```json:devbox.json
{
  "$schema":  "https://raw.githubusercontent.com/jetify-com/devbox/0.16.0/.schema/devbox.schema.json",
  "packages": ["python@3.12"],
  "shell": {
    "init_hook": [
      "echo 'Welcome to devbox!' > /dev/null"
    ],
    "scripts": {
      "test": [
        "echo \"Error: no test specified\" && exit 1"
      ]
    }
  }
}
```


# 4. devenv
[devenv](https://github.com/cachix/devenv) は Nix 言語で開発環境の設定を記述します。
**`flake.nix` を直接書くよりも、シンプルで読みやすい書き方になっています**。

**また、特定パッケージのバージョン指定やサービスの管理などを数行で記述できるのが便利です**。
`flake.nix` でこれらを記述するのは大変面倒であり、Nix 言語の知識も要求されるのでハードルが高くなりがちです。

筆者の環境で動作確認できていませんが、以下のように記述できます。

<!-- cspell:disable -->

```nix:devenv.nix
{ pkgs, lib, config, inputs, ... }:

{
  languages = {
    python = {
      enable = true;
      version = "3.11.2";
      uv.enable = true;
    };
  };

  packages = with pkgs; [ git ];

  enterShell = ''
    #python --version
  '';

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_15;
    initialDatabases = [{ name = "mydb"; }];
    extensions = extensions: [
      extensions.postgis
      extensions.timescaledb
    ];
    settings.shared_preload_libraries = "timescaledb";
    initialScript = "CREATE EXTENSION IF NOT EXISTS timescaledb;";
  };
}
```

<!-- cspell:enable -->


# 5. その他
LLM で検索させると、以下のように様々なツールが見つかるかと思います。
私は使ったことが無いツールですので、名前をあげるだけにしておきます。

<!-- cspell:disable -->

- [Flox](https://github.com/flox/flox)
- [devshell](https://github.com/numtide/devshell)

<!-- cspell:enable -->

:::message
**Nix 言語に慣れて `flake.nix` で思い通りに環境を作り上げるもよし、自分に合う Nix ラッパーを探すもよしだと思います**。
:::
