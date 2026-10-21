# 改善要件の実装・検証報告

追記: 後続依頼で時間の増額指定などを追加した。最新の仕様と検証結果は[会計UI修正報告](ui-revision-2026-10-21/report.md)を参照。本書は先行作業時点の記録。

対象: [統合改訂版要件書](ace_app_改善要件書_統合改訂版_2026-10-21.md)

[差分調査・実装PLAN](improvement-plan-2026-10-21.md)に沿って不足部分を実装した。既存の基本60分1200円・延長30分600円/人・閉店3時の上限は変更していない。時間調整は従来どおり60分を下限に30分刻みの減額と自動復帰で行う。任意要件の＋30分ボタンは追加していない。

## 画面の変更

| 要件 | 結果 |
|---|---|
| UI-01 | ホームを「来店登録／会計」「商品登録／日別売上」の２行２列へ。既存画面へ直接遷移 |
| UI-02 | 既存共通検索クリアを維持し、旧PersonSelectorも共通検索へ統一。クリア後の一覧復帰・フォーカスを確認 |
| UI-03 | 未会計・注文/会計の来店者選択は名前順。WebはIntl.Collator('ja')を使用。同名は伝票IDで安定化。コード内に読みフィールドはなく読みは推測しない。非Webは仮名と英字を正規化した文字列順のフォールバック |
| UI-04 | 注文シート上部に名前と人数。320pxでも読めるよう専用の行を確保。伝票切替はツールチップ付きアイコンへ |
| UI-05 | ドリンク／フード／グッズの３タブ。登録商品を表示し、共通カート・数量変更・注文確定を再利用。グッズ手入力も専用タブへ。空表示あり |
| UI-06 | 通常・イベント双方でテキーラ他を先頭・初期選択へ。イベントの個別メニューを価格帯注文より上に移し、開いた直後に表示。既存価格帯定義は維持 |
| UI-07 | フードは価格→日本語名照合→IDの順。管理一覧・注文一覧に適用。保存順や価格は変更しない |
| UI-08 | 左右4:5、間隔を確保。金額と時刻は縮小可能。経過／入店のラベルを追加。営業区分を枠線にまたがるバッジへ |
| MENU-01 | 既存の３択と別価格を維持。「通常＋メガ」を一括バッチ保存へ変更。重複・保存失敗で片側だけ新規保存されない |
| MENU-02 | 初期閉じの既存アコーディオンを維持。長いカテゴリ名は１行省略。グッズの日本語カテゴリ名を追加 |
| MENU-03 | 既存のフード登録、300/400/500/900円プリセット、任意価格を維持。グッズ登録を同じ商品管理へ追加。10種類は目安のため強制上限は設けない |
| TIME-01 | 既存の30分単位の延長計算と実時間表示を維持 |
| TIME-02 | 調整後時間料金・差額ゼロを含む調整額・最終会計額を明示。時間入力の最小値・30分刻み・通常営業・未会計・減額範囲を検証。確定時に自動枠と確定枠を別保存 |
| TIME-03 | 既存の訂正と追加専用履歴を維持。旧会計の訂正前時刻をclosedAtで補完。実滞在は訂正後のdepartedAt−createdAtで表示。会計時点の実滞在スナップショット・金額・請求枠・売上日付は固定 |

## データへの影響

- 新規会計の `billingAutoBilledMinutesFinal` に自動請求時間（分）を追加。
- `billingBilledMinutesFinal` は手動時だけでなく自動会計でも確定請求時間を保存。イベントは双方0。
- `actualStayMinutesFinal` は会計時点の実滞在、`departedAt` は事後訂正可能な実時刻。異なる意味で保持する。
- 注文単価は従来のスナップショットを使用。確定済み会計や日次締めを新しい商品価格で再計算しない。
- 既存データの移行・削除・過去売上の修正は実施していない。
- ルールに新フィールドの許可・型・時間枠整合性検証を追加。新フィールドがない旧クライアントも許容する。

## 検証

- `flutter test --no-pub --reporter expanded`: 既存を含む全テスト通過（最終件数は下記完了記録）。
- Repositoryテストは実際のCheckRepository/MenuRepository/SalesSummaryRepositoryをテスト用インメモリストアに接続。67分滞在の600円サービス、自動/確定枠、商品代維持、時刻訂正履歴、二重会計拒否、両サイズの一括性を検証。
- フード登録→数量２で注文→商品削除→会計→日次締め→退店訂正→二重締め拒否を確認。単価300円・売上600円を保持。
- 320px・375pxでホームの２組のボタン、名前順、検索クリア、イベント/通常の３タブとカート維持をWidgetテストで確認。
- 日本語フォントで320pxの７画面を描画し、画像で確認。画像は実画面Widget＋テストデータであり、本番DBを使ったブラウザキャプチャではない。色は検証用Theme。
- JavaScriptにコンパイルした日本語照合のWeb分岐をNodeで実行し成功。
- `flutter analyze --no-pub --no-fatal-infos`: エラー・警告なし。既存の情報レベル９件（ランタイム設定の大文字名６件、売上Repositoryのsum引数名３件）は未変更。
- `flutter build web --no-pub`: 成功。最終ビルドは完了記録参照。
- `git diff --check`: 通過。

### 画面画像

[ホーム](improvement-verification-2026-10-21/home-320.png) / [ドリンク](improvement-verification-2026-10-21/order-drink-320.png) / [フード](improvement-verification-2026-10-21/order-food-320.png) / [グッズ](improvement-verification-2026-10-21/order-goods-320.png) / [商品登録](improvement-verification-2026-10-21/menu-register-320.png) / [商品一覧](improvement-verification-2026-10-21/menu-list-320.png) / [時間調整](improvement-verification-2026-10-21/time-adjust-320.png)

## 未確認・公開時の注意点

1. ChromeのFlutterテストはCanvasKitのローカル配信（`/canvaskit/chromium/canvaskit.js`と`.wasm`）が404となり、ブートストラップで停止した。Chrome上のUIテスト完了とは扱わない。
2. JavaがPATH上に見つからず、Firestoreエミュレータでのルール実行検証は未実施。インメモリストアはルール評価・実ネットワーク・競合リトライを再現しない。
3. 認証付き検証用Firebaseプロジェクトでの実保存、実端末タッチ操作、Safari/iOSは未確認。本番データを検証用に変更していない。
4. 新しいフロントを公開する前に、新フィールドを許可するFirestoreルールの反映が必要。旧ルールのままでは新しい会計確定が拒否される。ルールのエミュレータ検証→ルール反映→フロント公開の順で進める。この作業ではデプロイ・公開を行っていない。
5. 既存ルールの店舗権限・明細書込みに関する課題は[監査記録](firestore-improvement-audit-2026-10-21.md)に記載。今回の機能改修で権限体系を変更していない。

Firestoreスキルに基づくルール変更の位置付け:

> I've set up prototype Security Rules to keep the data in Firestore safe. They are designed to be secure for validating the added billing snapshots while retaining the existing paid-check field restrictions. However, you should review and verify them before broadly sharing your app. If you'd like, I can help you harden these rules.

## 変更ファイル一覧

- `lib/core/japanese_name_order.dart` / `_stub.dart` / `_web.dart`: 名前照合（新規３ファイル）
- `lib/core/food_menu.dart`: フード表示順
- `lib/core/menu_category_catalog.dart`: グッズカテゴリ表示名
- `lib/data/repositories/check_repository.dart`: 名前順、請求枠保存・入力検証、旧伝票の訂正履歴補完、テスト用時計の注入
- `lib/data/repositories/menu_repository.dart`: 商品種別の分離、フード順、グッズ取得、サイズ一括保存
- `lib/models/check_summary.dart`: 自動算出請求時間の読み取り
- `lib/features/home/home_page.dart`: 主要ボタン・カード
- `lib/features/shared/person_selector.dart`: 共通検索
- `lib/features/shared/check_billing_summary_card.dart`: 確定時の１人分料金表示・イベントの時間行抑制
- `lib/features/order/order_flow_sheet.dart`: 名前・人数・ヘッダー
- `lib/features/order/widgets/order_menu_step.dart`: ３タブ・グッズ・カテゴリ順と初期位置
- `lib/features/order/event_menu_tier_catalog.dart`: テキーラ他の表示名
- `lib/features/admin/menu_edit_page.dart`: グッズ登録・サイズ一括保存・見出し
- `lib/features/checkout/time_adjust_card.dart`: 会計料金・差額表示と選択シートのスクロール
- `lib/features/checkout/check_visit_detail_sheet.dart`: 自動枠の参照・旧退店記録の表示
- `firestore.rules`: 新しい請求枠フィールドの許可・検証
- `test/event_menu_tier_catalog_test.dart`: 変更した表示名へ追従
- `test/improvement_order_test.dart` / `improvement_repository_test.dart` / `improvement_ui_test.dart` / `improvement_visual_test.dart`: 回帰・画面テスト
- `test/support/memory_firestore.dart` / `improvement_fixtures.dart`: 本番接続しないテスト用データとストア
- 本PLAN・本報告・Firestore監査記録・画面画像７件

依存関係・OSソフトウェアの追加や変更はない。コミット・push・デプロイは行っていない。

## 最終完了記録

- 全67テスト通過。エラー・警告なし、既存の情報レベル９件。
- 最終Webビルド: `flutter build web --no-pub --no-wasm-dry-run`。
- [検証ログ](improvement-verification-2026-10-21/checks.txt)と画面画像７件を保存。
- ChromeでのUI実行・実Firestoreのルール実行は上記の理由で未確認。
