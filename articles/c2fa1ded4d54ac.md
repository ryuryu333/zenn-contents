---
title: "C# xUnit を用いた単体テストの実装方法 Visual Studio 2022"
emoji: "😺"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [dotnet, csharp, 単体テスト, xunit]
published: true
published_at: "2025-03-23 07:00"
---

# はじめに

C# でアプリケーションを開発していると、関数や処理が正しく動作するかどうか確認したくなることがあります。

とはいえ、毎回 `Console.WriteLine()` で目視確認するのは手間がかかり、バグも見逃しがちです。

そこで本記事では、C# の単体テストフレームワーク **xUnit** を使って、Visual Studio 2022 上で簡単にテストを自動化する方法を解説します。

- C# でのテストが初めての方
- xUnit を使ってみたいけど使い方が分からない方
- Visual Studio 上での操作手順も一緒に確認したい方

そんな方に向けた内容になっています。

私自身、初めて xUnit を導入したときに GUI 操作でつまずいた経験があったので、今回は**スクリーンショット多め**で丁寧に解説してみました。


解説に使用したコードはこちらで公開しています。

https://github.com/ryuryu333/csharp_ci_sample


# アプリ プロジェクトの準備
## プロジェクトの作成
今回はコンソールアプリ（.NET Framework）テンプレートでプロジェクトを作成しました。

## コードの準備
クラス `Calculator` を作成し、クラス `Program` にて使用します。

```cs:Program
using System;

namespace MyConsoleApp
{
    class Program
    {
        static void Main()
        {
            Calculator myCalculator = new Calculator();
            int result = myCalculator.Add(1, 2);
            Console.WriteLine(result);
        }
    }
}
```

```cs:Calculator
using System;

namespace MyConsoleApp
{
    public class Calculator
    {
        public int Add(int input1, int input2)
        {
            return input1 + input2;
        }
    }
}
```

# xUnit を用いたテストの自動化
**作成したクラス `Calculator` にて関数 `Add()` が正常に動作することを確認するにはどうすべきでしょうか？**

`Add()` の引数を変えながら合っているのを確認するのは面倒です...。

**そこで、`xUnit` でテスト作業を自動化します。**

https://xunit.net/

https://learn.microsoft.com/ja-jp/dotnet/core/testing/unit-testing-with-dotnet-test

## テスト プロジェクトの作成
`ファイル` > `新規作成` > `プロジェクト` を選択します。

![プロジェクトの新規作成](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_2.webp)

xUnit で検索し、`xUnit テスト プロジェクト` を選択します。

![xUnitプロジェクトの検索](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_3.webp)

`ソリューション` の箇所を `ソリューションに追加` に変更します。

次へを押し、開発で使用している .NET のバージョンに合わせて、フレームワークを選択し、作成を押します。

![プロジェクトの設定](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_4.webp)

## アプリ プロジェクト への参照を追加
クラス `Calculator` をテスト プロジェクトから参照できるように設定します。

`ソリューションエクスプローラー` > `テスト用のプロジェクト名` > `参照` を右クリックします。
`参照の追加` を選択します。

![プロジェクトの参照追加1](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_5.webp)

画面左上にある `プロジェクト` > `ソリューション` をクリックします。
自身のアプリ プロジェクトの左側に☑を付け、OK で閉じます。

![プロジェクトの参照追加2](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_6.webp)

## テストコードの作成
xUnit でのテスト方法は以下の2つに大別できます。

- **動く/動かない を見るだけなら `[Fact]`**
- **入力によって出力が変化する なら `[Theory]`**

を使うと良いでしょう。

| 属性       | 主な特徴                                                       |
|------------|----------------------------------------------------------------|
| `[Fact]`   | 引数なしの基本テスト。毎回同じ条件で実行される固定テスト向き。 |
| `[Theory]` | 引数ありのパラメータ化テスト。複数の入力で同じ処理を検証できる。 |


**`[Theory]` では `[InlineData(1, 2, 3)]` のように `入力` と `想定される出力` をセットにして記述します。**

| 属性           | 向いている場面                                      | 主な特徴・判断ポイント                                  |
|----------------|---------------------------------------------------|----------------------------------------------------------|
| `[InlineData]` | 少数・単純なデータを直接書きたいとき                | すぐに見える場所に書けて簡潔。データが少ないときに最適   |
| `[MemberData]` | 少し複雑 or 複数の組み合わせを使い回したいとき     | 配列・リストなどを静的に返せるならこれで十分            |
| `[ClassData]`  | 複雑なロジック or 外部データや動的生成が必要なとき | 独自クラスで柔軟な処理が可能。データが大量・動的なとき   |

**コード例を示します。**

```cs:CalculatorTest
using Xunit;
using MyConsoleApp;
using System.Collections;
using System.Collections.Generic;

namespace MyTest
{
    public class CalculatorTest
    {
        // MyConsoleApp のテストしたいクラスをインスタンス化
        private readonly Calculator _calculator = new();

        [Fact]
        public void AddTestFact()
        {
            Assert.Equal(3, _calculator.Add(1, 2));
        }

        // InlineData を使ったパターン
        [Theory]
        [InlineData(1, 2, 3)]
        [InlineData(2, 3, 5)]
        public void AddTestTheory(int input1, int input2, int expected)
        {
            int actual = _calculator.Add(input1, input2);
            Assert.Equal(expected, actual);
        }

        // MemberData を使ったパターン
        [Theory]
        [MemberData(nameof(AddTestMemberData))]
        public void AddTestMember(int a, int b, int expected)
        {
            Assert.Equal(expected, _calculator.Add(a, b));
        }

        public static IEnumerable<object[]> AddTestMemberData =>
            new List<object[]>
            {
                    new object[] { 1, 2, 3 },
                    new object[] { 5, 7, 12 }
            };

        // ClassData を使ったパターン
        [Theory]
        [ClassData(typeof(AddTestData))]
        public void AddTestClassData(int a, int b, int expected)
        {
            int result = _calculator.Add(a, b);
            Assert.Equal(expected, result);
        }
    }

    // ClassData 用のテストデータクラス
    public class AddTestData : IEnumerable<object[]>
    {
        public IEnumerator<object[]> GetEnumerator()
        {
            yield return new object[] { 10, 20, 30 };
            yield return new object[] { -5, 5, 0 };
            yield return new object[] { 100, 200, 300 };
        }

        IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
    }
}
```

## テストの実行
`テスト` > `テスト エクスプローラー` をクリックします。

![テストエクスプローラーを開く方法](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_7.webp)

`テスト エクスプローラー` 画面の左上にある `矢印ボタン` を押すと全てのテストが実行されます。

![テストの実行](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_8.webp)

**テストが通らない場合は、`赤い×印` で表示されます。**

該当の行を選択すれば、実際の値が確認できます。
今回だと、想定出力が `4` であるのに対して、出力が `3` であったと分かります。

![テスト失敗時](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_9.webp)

## 便利な小ネタ
### テスト名を指定する
テスト結果には関数名が表示されます。

**`DisplayName` を用いると、任意の名前を表示させることが出来ます。**

![テスト名を指定する](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_10.webp)

```cs:CalculatorTest
using Xunit;
using MyConsoleApp;
using System.Collections;
using System.Collections.Generic;

namespace MyTest
{
    public class CalculatorTest
    {
        // MyConsoleApp のテストしたいクラスをインスタンス化
        private readonly Calculator _calculator = new();

        [Fact(DisplayName = "好きな名前を表示できる")]
        public void AddTestDisplayName()
        {
            Assert.Equal(3, _calculator.Add(1, 2));
        }
    }
}
```

### ログを出力する
テスト実行時のログを確認したい場合、`Console.WriteLine` では上手くログを表示できません。

**`ITestOutputHelper` を利用すると、ログが確認できるようになります。**

![ログを出力する](/images/c2fa1ded4d54ac/c2fa1ded4d54ac-2025-3-22_11.webp)

```cs:CalculatorTest
using Xunit;
using MyConsoleApp;
using System.Collections;
using System.Collections.Generic;

namespace MyTest
{
    public class CalculatorTest
    {
        // MyConsoleApp のテストしたいクラスをインスタンス化
        private readonly Calculator _calculator = new();

        private readonly ITestOutputHelper _output;

        public CalculatorTest(ITestOutputHelper output)
        {
            _output = output;
        }

        [Fact]
        public void AddTestLog()
        {
            Assert.Equal(3, _calculator.Add(1, 2));
            _output.WriteLine("ログを表示できます");
            Console.WriteLine("こっちは表示されない");
        }
    }
}
```

# おわりに
ここまで、xUnit を使って C# の関数に対する単体テストを実装する手順を、Visual Studio 2022 の画面操作とともに紹介してきました。

テストを自動化することで、バグの早期発見や安心してリファクタリングできる環境が整ってきます。

次のステップは、**CI（継続的インテグレーション）** の導入です。

Push や Pull Request のタイミングでテストが自動実行される仕組みを整えることで、さらに効率的な開発が可能になります。

https://zenn.dev/trifolium/articles/6f6fe5c8746798
