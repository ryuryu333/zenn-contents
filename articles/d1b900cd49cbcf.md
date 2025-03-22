---
title: "ローカル dll に依存した環境での自動テスト"
emoji: "🎉"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: []
published: false
---


## ローカル dll を参照に登録
`ソリューションエクスプローラー` > `プロジェクト名` > `参照` を右クリックします。
`参照の追加` を選択します。

![参照追加画面へのアクセス](/images/d1b900cd49cbcf/d1b900cd49cbcf-2025-3-22_1.webp)

`画面右下の参照` をクリックし、登録したい dll を選択します。
登録した dll は `画面左の参照` をクリックすると、画面中央に表示されます。
dll の名前の左側に☑が付いているのを確認して、`ok` で画面を閉じます。 

![dllの登録](/images/d1b900cd49cbcf/d1b900cd49cbcf-2025-3-22.webp)

```cs:UseLocaldll
using System;
using CeVIO.Talk.RemoteService2; //参照登録した dll

namespace MyConsoleApp
{
    public class UseLocaldll
    {
        public void SomeMethod()
        {
            // CeVIO.Talk.RemoteService2.dll にて定義されたクラスを使用する
            ServiceControl2.StartHost(false);
        }
    }
}
```