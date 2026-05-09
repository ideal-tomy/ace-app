import '../models/expense_account_item.dart';
import '../models/finance_entry.dart';

/// Firestore と CSV で使う確定済みの accountItemId（旧データは category を推測）。
String resolvedExpenseAccountItemId(FinanceEntry e) {
  final raw = e.accountItemId?.trim();
  if (raw != null && raw.isNotEmpty) return raw;
  return expenseAccountIdForCategoryLabel(e.category) ?? '';
}

/// 集計用キー。[resolvedExpenseAccountItemId] が取れれば id、それ以外は表示用 category で束ねる。
String expenseEntryGroupingKey(FinanceEntry e) {
  final id = resolvedExpenseAccountItemId(e);
  if (id.isNotEmpty) return id;
  final c = e.category.trim();
  return c.isEmpty ? '（未分類）' : 'legacy::$c';
}

/// [expenseEntryGroupingKey] の結果を一覧表示用ラベルに変換する。
String expenseGroupingLabel(String groupKey) {
  if (groupKey == '（未分類）') return groupKey;
  if (groupKey.startsWith('legacy::')) {
    return groupKey.substring('legacy::'.length);
  }
  return expenseAccountItemById(groupKey)?.labelJa ?? groupKey;
}

/// 明細行の科目表示（マスタに載っていれば正規ラベル、なければ従来の category）。
String entryDisplayExpenseCategory(FinanceEntry e) {
  final id = resolvedExpenseAccountItemId(e);
  if (id.isNotEmpty) {
    return expenseAccountItemById(id)?.labelJa ?? e.category;
  }
  final c = e.category.trim();
  return c.isEmpty ? '（未分類）' : c;
}

/// Excel 総合計シート・経費ブロック準拠（小計・差引行は含まない）。
const kExpenseAccountItems = <ExpenseAccountItem>[
  ExpenseAccountItem(id: 'taxes_and_dues', labelJa: '租税公課', sortOrder: 1),
  ExpenseAccountItem(id: 'utilities', labelJa: '水道光熱費', sortOrder: 2),
  ExpenseAccountItem(
    id: 'travel_transportation',
    labelJa: '旅費交通費',
    sortOrder: 3,
  ),
  ExpenseAccountItem(id: 'communication', labelJa: '通信費', sortOrder: 4),
  ExpenseAccountItem(id: 'advertising', labelJa: '広告宣伝費', sortOrder: 5),
  ExpenseAccountItem(id: 'entertainment', labelJa: '接待交際費', sortOrder: 6),
  ExpenseAccountItem(id: 'vehicle', labelJa: '車両費', sortOrder: 7),
  ExpenseAccountItem(id: 'insurance_premium', labelJa: '損害保険料', sortOrder: 8),
  ExpenseAccountItem(id: 'repairs', labelJa: '修繕費', sortOrder: 9),
  ExpenseAccountItem(id: 'supplies', labelJa: '消耗品費', sortOrder: 10),
  ExpenseAccountItem(id: 'depreciation', labelJa: '減価償却費', sortOrder: 11),
  ExpenseAccountItem(id: 'welfare', labelJa: '福利厚生費', sortOrder: 12),
  ExpenseAccountItem(id: 'salaries_wages', labelJa: '給料賃金', sortOrder: 13),
  ExpenseAccountItem(id: 'interest_discounts', labelJa: '利子割引料', sortOrder: 14),
  ExpenseAccountItem(id: 'rent_land_building', labelJa: '地代家賃', sortOrder: 15),
  ExpenseAccountItem(id: 'dues', labelJa: '諸会費', sortOrder: 16),
  ExpenseAccountItem(id: 'outsourced_labor', labelJa: '外注工賃', sortOrder: 17),
  ExpenseAccountItem(id: 'support_fees', labelJa: 'サポート費', sortOrder: 18),
  ExpenseAccountItem(
    id: 'family_employee_salary',
    labelJa: '専従者給与',
    sortOrder: 19,
  ),
  ExpenseAccountItem(id: 'freight', labelJa: '運賃', sortOrder: 20),
  ExpenseAccountItem(id: 'rental', labelJa: 'レンタル', sortOrder: 21),
  ExpenseAccountItem(id: 'miscellaneous', labelJa: '雑費', sortOrder: 22),
];

/// [id] → 科目。不明な id は null。
ExpenseAccountItem? expenseAccountItemById(String id) {
  for (final item in kExpenseAccountItems) {
    if (item.id == id) return item;
  }
  return null;
}

/// 旧データの `category`（日本語）から [id] を推測。完全一致のみ。
String? expenseAccountIdForCategoryLabel(String category) {
  final t = category.trim();
  if (t.isEmpty) return null;
  for (final item in kExpenseAccountItems) {
    if (item.labelJa == t) return item.id;
  }
  return null;
}
