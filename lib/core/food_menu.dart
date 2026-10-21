import '../models/menu_item.dart';
import 'japanese_name_order.dart';

/// 常設フードマスタのカテゴリ（menus に保存）。
const kFoodRegisteredCategory = 'FOOD';

/// 注文時に手打ちしたフードのカテゴリ（menus には保存しない）。
const kFoodDailyCategory = 'FOOD_DAILY';

const kFoodQuickPrices = [300, 400, 500, 900];

int compareFoodMenus(MenuItem a, MenuItem b) {
  final price = a.priceTaxIncluded.compareTo(b.priceTaxIncluded);
  if (price != 0) return price;
  final name = compareJapaneseNames(a.name, b.name);
  return name != 0 ? name : a.id.compareTo(b.id);
}

/// 同名判定用。前後空白と全角/半角スペースの連続、英字の大小を無視する。
String normalizeFoodMenuName(String name) {
  return name.trim().replaceAll(RegExp(r'[\s\u3000]+'), ' ').toLowerCase();
}

bool isRegisteredFoodMenu(MenuItem item) =>
    item.category == kFoodRegisteredCategory;

bool isFoodOrderCategory(String category) =>
    category == kFoodRegisteredCategory || category == kFoodDailyCategory;

bool hasDuplicateFoodName(Iterable<String> existingNames, String name) {
  final target = normalizeFoodMenuName(name);
  return existingNames.any((n) => normalizeFoodMenuName(n) == target);
}
