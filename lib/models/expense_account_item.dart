/// 経費科目（Excel 総合計シート「経費」ブロックの実勘定に準拠）。
class ExpenseAccountItem {
  const ExpenseAccountItem({
    required this.id,
    required this.labelJa,
    required this.sortOrder,
  });

  /// CSV・DB 用の安定キー（snake_case）。
  final String id;

  /// 画面表示・従来の `category` フィールドに保存する日本語ラベル。
  final String labelJa;

  /// 一覧・集計の並び順。
  final int sortOrder;
}
