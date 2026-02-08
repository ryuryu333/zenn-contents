---
title: "第三部 システム環境の管理（Mac 限定）"
---

# 1. この章でやること
この章では、Mac 全体レイヤー（`mac-*`）の進め方を整理します。

**nix-darwin で Homebrew と macOS 設定まで宣言管理するための導線**を示します。


# 2. 前提
このレイヤーは、共通レイヤー（`entrypoint-01`, `common-01` 〜 `common-04`）とユーザー環境レイヤー（`user-01` 〜 `user-05`）が完了している前提です。

:::message
ユーザー環境レイヤー未完了でも進めることは可能ですが、運用の一貫性を重視するなら `user` レイヤー完了後をおすすめします。
:::


# 3. 読む章
以下の順で進めます。

[次の章へ](/<ユーザー名>/<本のスラッグ>/viewer/c02)

1. `mac-02`: nix-darwin のインストール
2. `mac-03`: nix-darwin の基本操作
3. `mac-04`: nix-darwin で home-manager を管理
4. `mac-05`: nix-darwin で Homebrew を管理
5. `mac-06`: nix-darwin で Mac 本体設定を管理


# 4. このレイヤーの完了条件
以下を満たしていれば、このレイヤーは完了です。

1. `sudo darwin-rebuild switch` で環境を再構築できる
2. Homebrew のツールを `configuration.nix` で管理できる
3. Mac 本体設定（`defaults` 相当）を宣言管理できる


# 5. 次に進む判断
この先は運用方針で分岐します。

1. プロジェクトごとの再現性を高めたい: `dev-01` へ進む
2. Mac 全体管理が目的だった: ここで止めて運用開始
