# Firestore変更前調査・ルール監査

Flutter/Dart。SDKは既存cloud_firestore。ルール変更は請求時間スナップショットの追従に限定する。

## アクセス・モデル

- stores/{storeId}/checks: status=open の一覧、全件から売上をクライアント集計。items は orderedAt降順、存在確認limit(1)。visit_corrections は correctedAt降順。
- menus: 全件、isActive=true、category一致、初期登録limit(1)。name/categoryは文字列、単価/sortOrderは整数、isActiveはbool。FOOD、DARTS_GOODSも同じ構造。
- customers: displayName一致limit(1)、displayName順。
- users: 店舗内の権限ドキュメント。admin_auth_serviceには旧トップレベルusersの読み取り互換も存在。
- daily_closings: 日付ID、配下checksはclosedAt順。確定売上スナップショットで更新禁止。
- accounting_entries / expense_entries: 経費はdate降順、本人のcreatedBy一致＋date降順。
- admins/{email}: 旧管理者互換。認証はFirebase Auth Email/Password。既存仕様でメール認証利用者を店舗管理者として扱う。
- checksの注文追加/数量変更/取消/会計/退店訂正は既存transaction。退店訂正はdepartedAtのみ、履歴は追加専用。新規のbillingAutoBilledMinutesFinalは整数分、0または60以上30分単位、確定枠以上。旧伝票・旧クライアントはフィールド欠落を許容。

## 監査結果（既存の権限課題を含む）

```json
{
  "score": 2,
  "summary": "今回の請求枠追加は権限を拡張しない。既存ルール全体は複数店舗での公開前に権限設計の見直しが必要。",
  "findings": [
    {"check":"Authority Source / Field-Level vs Identity-Level", "severity":"major", "issue":"メール付き認証ユーザーが任意店舗の管理者として扱われる既存仕様。", "recommendation":"店舗所属のサーバー管理ACLを採用する別タスクで対応。今回の要件では変更しない。"},
    {"check":"Update Bypass / Type Safety", "severity":"major", "issue":"未会計伝票のopen→openとitemsの書込みは広く許可され、合計や型の完全な検証はない。", "recommendation":"注文トランザクションの整合性を含めて段階的に検証を強化する。今回追加の時間指定は型・最小値・30分単位を検証する。"},
    {"check":"Storage Abuse", "severity":"minor", "issue":"訂正履歴の件数・一般伝票/明細の文字列長の制限は網羅されていない。", "recommendation":"別途スキーマ検証と利用量監視を検討する。"}
  ]
}
```

新旧会計クライアントの互換を保つため新フィールドは任意とし、存在時のみ検証する。会計済みデータの訂正は金額・枠を変更できない制約を維持する。エミュレータでの実行結果は実装報告へ記載する。

## 後続の時間増額対応

会計UI修正依頼に従い、時間調整額の負数（増額）を許容した。`自動料金 = 確定時間料金 + 調整額`、非負の自動・確定時間料金、確定済みデータの更新制限は維持する。自動枠と確定枠の大小比較を外し、60分以上・30分単位・1440分以下を検証する。Repositoryではさらに伝票の起算時刻から閉店３時までの上限を検証する。

追加フィールドや移行はない。権限の拡張はなく、前記の既存権限課題は未変更。Rulesのエミュレータ検証・反映は未実施。詳しくは[後続報告](ui-revision-2026-10-21/report.md)を参照。
