# Firebase 売上・経費集計の現状検証と実装計画

更新日: 2026-08-06  
対象: `ace_app`（Flutter Web + Firebase Authentication + Cloud Firestore）

## 1. 結論

このアプリを中心に、イベント売上、通常営業売上、経費、日別損益を Firebase 上で一元管理することは可能である。

現状は次の段階にある。

- 注文と会計: イベント当日に使う最低限の機能と保存データはある。
- 経費: 日付付き保存、月・年・科目別集計、CSV出力まで実装済み。
- 売上集計: 集計に必要な金額と時刻は保存されるが、会計済み伝票の一覧・期間検索・CSV・日別集計は未実装。
- 一元管理: 実現可能。ただし「営業日」「イベント」「支払方法」を売上データに追加し、売上と経費を共通の期間で集計する画面が必要。

イベント前は既存の注文・会計フローを大きく変更せず、まず会計済み伝票を使った読み取り専用の売上集計ページを追加するのが安全である。その後、営業日やイベントIDなどを追加する。

## 2. 現在の Firestore データ構造

すべての主要データは次の店舗配下に保存される。

```text
stores/{storeId}
├─ customers/{customerId}
├─ checks/{checkId}
│  └─ items/{itemId}
├─ menus/{menuId}
├─ accounting_entries/{entryId}
├─ expense_entries/{entryId}
└─ users/{uid}
```

### 2.1 売上伝票 `checks`

来店登録時に以下が保存される。

```text
customerId
customerNameSnapshot
peopleCount
billingMode              event / normal
status                   open / paid
subtotalTaxIncluded
taxAmount
totalTaxIncluded
createdAt                サーバー時刻
closedAt                 会計時にサーバー時刻を設定
```

会計確定時には以下も保存される。

```text
finalAmount
timeChargeFinal
merchandiseFinal
separateFinal
```

注文明細 `checks/{checkId}/items/{itemId}` には、商品名、カテゴリ、単価、数量、行合計、注文時刻が保存される。メニューのスナップショットを保存しているため、後でメニュー価格を変更しても過去売上の明細は維持される。

### 2.2 経費 `expense_entries`

経費には以下が保存される。

```text
date                     日付の Timestamp（時刻は 00:00）
accountItemId
category
amount
memo
createdBy
updatedAt
```

既存画面で次の処理ができる。

- 自分が入力した経費の一覧
- 管理者による全件表示
- 今月、今年、全期間の絞り込み
- 科目別合計
- CSVダウンロード

したがって、経費管理はすでに日付単位の運用が可能である。ただし任意の日付範囲、日別合計、売上との損益比較は未実装である。

### 2.3 `accounting_entries` の位置づけ

`accounting_entries` へ任意の会計データを保存するメソッドは存在するが、現在の会計確定処理からは呼ばれていない。現在の売上の正本は `checks` である。

当面は、売上を `checks` と `accounting_entries` の両方へ重複保存しない。二重保存すると、一方だけ成功した場合や修正時に金額が食い違うためである。売上集計は `status == paid` の `checks` を正本として行う。

## 3. 現状データで可能な集計

既存の会計済み伝票から、追加のデータ移行なしで次を計算できる。

- 会計日時別の売上合計
- イベント営業と通常営業の売上内訳
- 会計件数
- 来店人数
- 客単価（売上 ÷ 人数）
- 伝票単価（売上 ÷ 伝票数）
- 顧客名・ニックネーム別売上
- 商品別の販売数量・売上
- カテゴリ別売上
- 時間料金、飲食、物販売上の内訳

ただし、現在のデータだけでは次を正確に集計できない。

- 現金、カード、電子決済など支払方法別売上
- 複数回開催したイベントごとの売上
- テーブル・組ごとの売上
- 取消・返金・値引きの理由と金額
- 会計担当スタッフ別実績
- 3:00までを前日の営業として扱う厳密な営業日集計

## 4. 日付管理で先に決めること

### 4.1 `createdAt` と `closedAt` の用途

- `createdAt`: 来店・伝票作成日時
- `closedAt`: 売上が確定した会計日時
- 売上計上基準: 原則として `closedAt`

注文した日ではなく、会計が確定した営業日の売上として扱う。

### 4.2 カレンダー日と営業日

深夜営業の場合、午前1時の会計を日付どおり翌日売上にするか、前日の営業売上にするかで集計結果が変わる。

営業日の切り替えは、実際の運用ルールに合わせて午前6時に固定する。

```text
会計時刻が 00:00 ～ 05:59 → 前日を businessDate とする
会計時刻が 06:00 以降       → 当日を businessDate とする
```

保存例:

```text
closedAt:     2026-08-07 01:20:00+09:00
businessDate: 2026-08-06 00:00:00+09:00
```

集計のたびに端末側で計算するのではなく、会計確定時に `businessDate` を保存する。サーバー時刻と Asia/Tokyo の扱いを統一すること。

## 5. 推奨する追加データモデル

### 5.1 伝票への追加フィールド

```text
eventId                  イベントでない場合は null
businessDate             売上を計上する営業日
paymentMethod            cash / card / qr / other
tableLabel               組名・テーブル番号（任意）
closedBy                 会計確定した Firebase Auth UID
updatedAt                最終更新のサーバー時刻
schemaVersion            例: 2
```

金額は整数の円で保存する。表示用文字列やカンマ付き金額は保存しない。

### 5.2 イベントコレクション

```text
stores/{storeId}/events/{eventId}
```

推奨フィールド:

```text
name                     イベント名
businessDate             営業日
startsAt
endsAt
status                   planned / active / closed
notes
createdAt
createdBy
```

伝票側に `eventId` を保持すれば、同じ日に複数イベントがあっても分けて集計できる。最初の実装ではイベントを1件作成し、イベント営業で作る伝票へ自動設定する形でよい。

### 5.3 日次サマリー（将来）

初期段階では `checks` と `expense_entries` を直接問い合わせて集計する。データ量が増えて画面が遅くなった段階で、次を追加する。

```text
stores/{storeId}/daily_summaries/{yyyy-MM-dd}
```

例:

```text
businessDate
grossSales
expenseTotal
netCashFlow
checkCount
guestCount
salesByPaymentMethod
salesByBusinessMode
updatedAt
```

このサマリーは表示高速化用であり、正本は引き続き `checks` と `expense_entries` とする。Cloud Functions で会計確定・経費変更を検知して再計算するか、管理者操作で再構築できるようにする。

## 6. 最初に実装する「売上集計ページ」

### 6.1 最小構成

新しい管理者ページに次を表示する。

- 期間: 今日、今月、任意期間、すべて
- 営業種別: すべて、イベント、通常
- 売上合計
- 会計件数、人数、客単価
- 会計済み伝票一覧
- 商品別販売数量・売上
- CSVダウンロード

初回は `closedAt` を基準に期間検索する。`businessDate` 導入後は営業日基準へ切り替える。

### 6.2 推奨ファイル

```text
lib/models/sales_summary.dart
lib/data/repositories/sales_summary_repository.dart
lib/features/admin/sales_summary_admin_page.dart
```

既存の以下を再利用できる。

- `CheckSummary`
- `CheckItem`
- `csv_download.dart`
- 経費集計ページの期間フィルター、DataTable、CSVセル処理

### 6.3 Firestore クエリ

基本クエリ:

```text
stores/{storeId}/checks
  where status == paid
  where closedAt >= 開始日時
  where closedAt < 終了日時
  orderBy closedAt desc
```

必要になる複合インデックスの例:

```json
{
  "collectionGroup": "checks",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "closedAt", "order": "DESCENDING" }
  ]
}
```

`businessDate` と `eventId` 導入後は、それぞれを条件にした複合インデックスも追加する。実際にアプリが使うクエリと一致するインデックスだけを管理する。

### 6.4 売上CSVの推奨列

伝票CSV:

```text
businessDate,closedAt,eventName,billingMode,checkId,customerName,
tableLabel,peopleCount,paymentMethod,finalAmount,taxAmount,
timeChargeFinal,merchandiseFinal,closedBy
```

商品CSV:

```text
businessDate,eventName,checkId,customerName,menuId,menuName,
category,unitPrice,qty,lineTotal,orderedAt
```

伝票CSVと商品CSVは分ける。1つに混ぜると、伝票金額が明細数だけ重複して表計算ソフトで誤集計しやすい。

## 7. 売上・経費一元管理ページ

売上集計が動いた後、管理者向けに次のダッシュボードを追加する。

```text
売上              paid checks の finalAmount 合計
経費              expense_entries の amount 合計
差引              売上 - 経費
```

表示候補:

- 今日／今月／今年／任意期間
- 日別の売上、経費、差引
- 営業種別別売上
- 支払方法別売上
- 経費科目別合計
- 商品別売上ランキング
- イベント別収支
- CSV出力

ここで表示する「差引」は簡易的な資金収支であり、税務上の利益や正式な損益計算書とは区別する。仕入原価、在庫、減価償却、未払金などを扱う場合は別途会計設計が必要になる。

## 8. 段階的な実装手順

### Phase 0: イベント前のデータ保全確認

1. Firebase Console で `checks` に `createdAt` が入ることを確認する。
2. テスト会計後に `status=paid`、`closedAt`、`finalAmount` が入ることを確認する。
3. `items` の明細合計と伝票の `finalAmount` が一致することを確認する。
4. テスト用の顧客名に `[TEST]` を付け、本番データと区別する。
5. テストデータを削除する場合は、親 `check` だけでなく `items` サブコレクションも対象になる点に注意する。

### Phase 1: 既存データだけで売上集計を実装

1. `SalesSummaryRepository` を追加する。
2. `status == paid` と `closedAt` の期間クエリを追加する。
3. `SalesSummaryAdminPage` を追加する。
4. 合計、件数、人数、客単価、伝票一覧を表示する。
5. 伝票CSVと商品CSVを出力する。
6. 必要な `checks` 複合インデックスを追加する。
7. 管理者だけが集計ページを開けるルートを追加する。

### Phase 2: 営業日とイベント管理を追加

1. `events` コレクションとイベント作成画面を追加する。
2. 来店登録時にイベントを選択または自動設定する。
3. `checks` に `eventId` と `businessDate` を保存する。
4. 会計時に `paymentMethod` と `closedBy` を保存する。
5. 集計ページへ営業日・イベント・支払方法フィルターを追加する。
6. 既存伝票は `closedAt` から `businessDate` を補完する移行処理を用意する。

### Phase 3: 売上と経費の一元ダッシュボード

1. 経費集計を任意期間に対応させる。
2. 売上と経費の期間境界を共通化する。
3. 日別の売上・経費・差引を表示する。
4. イベント別収支を表示する。
5. 統合CSVを追加する。

### Phase 4: データ量増加への対応

1. Cloud Functions で日次サマリーを生成する。
2. 再計算可能な管理処理を用意する。
3. ページネーションを追加する。
4. Firestore の読み取り件数と費用を監視する。
5. 定期的なエクスポートまたはバックアップ運用を決める。

## 9. テスト計画

### 9.1 最小テストデータ

次の会計済み伝票を作成する。

| ケース | 営業種別 | 人数 | 注文 | 期待金額 |
|---|---:|---:|---|---:|
| A | イベント | 1 | 500円 × 2 | 1,000円 |
| B | イベント | 4 | 700円 × 3 | 2,100円 |
| C | イベント | 2 | 500円 + 1,000円 | 1,500円 |

期待値:

```text
売上合計: 4,600円
会計件数: 3件
人数: 7名
商品数量: 7点
```

経費として1,200円と800円を同じ日へ登録した場合:

```text
経費合計: 2,000円
簡易差引: 2,600円
```

### 9.2 必須確認項目

- 同じ期間を選んだとき、画面合計とCSV合計が一致する。
- `open` の伝票は売上に含まれない。
- `paid` になった伝票だけが1回含まれる。
- 0時前後と6時前後の営業日判定が仕様どおりになる。
- イベントと通常営業を分けても、両者の合計が全体売上と一致する。
- 商品明細の合計と伝票合計に差がある場合、検出して警告できる。
- 経費の追加・更新・削除後に集計が更新される。
- スタッフ権限では全体売上・全体経費を閲覧できない。

### 9.3 実データ投入前の受け入れ条件

- 集計対象期間を明示できる。
- タイムゾーンが Asia/Tokyo で統一される。
- 画面、伝票CSV、商品CSVの金額が一致する。
- 同じ会計が重複表示されない。
- 会計済み伝票を通常操作で変更できない。
- テストデータを本番集計から除外できる。

## 10. セキュリティと整合性の実装条件

集計ページを追加するだけなら書き込み権限を増やす必要はない。集計は管理者の読み取り専用から始める。

今後ルールを更新するときは、少なくとも次を満たす。

- 店舗に所属するユーザーだけが店舗データを読める。
- 売上集計と全経費集計は管理者だけが読める。
- `checks` の作成・更新で型、金額範囲、必須フィールドを検証する。
- `paid` 伝票の金額・明細を通常スタッフが変更できない。
- `businessDate`、`closedAt`、`closedBy` の不正な変更を禁止する。
- `expense_entries` の金額、日付、文字列長、許可フィールドを検証する。
- `daily_summaries` はクライアントから直接書き込ませない。

ルール変更後は Emulator Suite で、未ログイン、通常スタッフ、経費入力者、管理者の各権限をテストしてからデプロイする。

## 11. 運用上の注意

- Firebase Console での手修正は監査履歴がアプリに残らないため、通常運用では避ける。
- 返金や取消はデータ削除ではなく、理由・実行者・時刻を残す訂正処理として設計する。
- 顧客名は表示用スナップショットとして残し、顧客マスタ変更で過去伝票名を自動変更しない。
- 日次集計は元データから再生成できるようにする。
- CSVは定期的に保管し、Firebase のバックアップ方針も別途決める。
- Firebase CLI を使う場合は `npx -y firebase-tools@latest` に統一する。

## 12. 推奨する次の作業

最初の開発単位は Phase 1 とする。既存の会計処理を書き換えずに、会計済み `checks` を読むだけの売上集計ページを追加できるため、イベント前後のリスクが低い。

Phase 1 の完成後、実際のイベントデータを使って必要な集計軸を確認し、Phase 2 で `eventId`、`paymentMethod` を追加する。この順番なら、現在の最低限の運用を維持しながら一元管理へ拡張できる。同じ営業日にイベント会計と通常営業会計が混在しても、共通の `businessDate` 内で `billingMode` により合算表示と種別表示の両方を行える。

## 13. 実装済みの日次締め（2026-08-07）

日別売上ページに次を実装した。

- 午前6時区切りの営業日ごとの未会計件数表示
- 未会計が0件の場合だけ有効になる「この営業日を締める」操作
- イベントと通常営業を合算した営業日全体の確定
- `daily_closings/{yyyy-MM-dd}` への日次合計保存
- `daily_closings/{yyyy-MM-dd}/checks/{checkId}` への伝票スナップショット保存
- 日次サマリーCSV
- 確定伝票明細CSV

日次締めは最大450伝票を1回のトランザクションで保存する。締め後の文書とスナップショットはクライアントから更新・削除できない。CSVは現在の伝票ではなく締め時点のスナップショットから再生成する。

デプロイ対象にはアプリ本体のほか、`firestore.rules` が含まれる。新しい集計ページは全伝票を取得してアプリ側で営業日・状態を分類するため、日次締め機能自体に新しい複合インデックスは不要である。
