---
title: "flake.nix をリモートに反映させずに使う"
---

# 1. この章でやること
この章では、`flake.nix` を GitHub のリモートレポジトリへ Push せずに利用する方法を解説します。

:::message
チームに導入はできないが、自分のローカルでは devShell を使いたい場合に使えます。
:::


# 2. flake.nix の仕様
**前提知識ですが、`flake.nix` が保存されているレポジトリが Git 管理されているか否かで `nix develop` の挙動が変わります**。

Git 管理されていない場合、`flake.nix` があるディレクトリ以下のフォルダ・ファイルが `nix/store` にコピーされから、devShell の起動処理が始まります。

**一方、Git 管理されていると、Git に追跡されているファイルのみを `nix/store` にコピーします**。
`git add` されていない場合、または、gitignore されているファイルは無視されます。

:::message
gitignore されていれば、バイナリなどの容量が大きいファイルをコピーせずに済むので、`nix develop` の起動が早くなります。
:::

具体的な数値データが見たい方は、こちらの検証記事の `4.4 巨大ファイルを追加した場合` をご覧ください。
`git add` 前後で速度に明確な差が生じます。

https://zenn.dev/trifolium/articles/da11a428c53f65#4.4-%E5%B7%A8%E5%A4%A7%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%82%92%E8%BF%BD%E5%8A%A0%E3%81%97%E3%81%9F%E5%A0%B4%E5%90%88


# 3. ローカルだけで使いたい場合
## 3.1 ローカルのみ Git 追跡状態にする
先述の通り、Git 管理下のディレクトリでは Git に追跡されていないファイルは評価対象になりません。
**そのため、`flake.nix` を `git add` するのは事実上必須です**。

この場合、以下のコマンドを使うと便利です。

```zsh:Zsh
git add --intent-to-add flake.nix
git update-index --assume-unchanged flake.nix
```

**`flake.nix` をローカルで追跡しつつ、ステージングしない & 変更を無視できます**。

ただし、`git rebase` などの操作で破綻する可能性はあるので、お気をつけください（`git stash` `git stash pop` で対策はできる...はず）。


## 3.2 develop コマンドのオプションを使う
先ほどの方法は `flake.nix` の仕様を逆手に取った裏技的な方法です。
**Nix に用意されている機能で丁寧に対策するなら、以下のような方法もあります**。

まず、`flake.nix` を Git が無視するように設定します。

```zsh:Zsh
printf "\n/flake.nix\n" >> .git/info/exclude
```

そして、カレントディレクトリを Path に指定した状態で devShell を起動します。

```zsh:Zsh
nix develop path:.
```

:::message
**nix-direnv を使っている場合**。

```zsh:Zsh
echo "use flake path:." >> .envrc
direnv allow
```

`use flake path:.` とすると、`nix develop path:.` 相当のコマンドになります。
:::


:::message
**ただし、この方法の場合、Git 管理していないファイルも参照されるため、プロジェクトサイズが大きい場合、devShell 起動時間が長くなると思われます**。
:::
