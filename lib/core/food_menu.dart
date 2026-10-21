import '../models/menu_item.dart';

/// 常設フードマスタのカテゴリ（menus に保存）。
const kFoodRegisteredCategory = 'FOOD';

/// 注文時に手打ちしたフードのカテゴリ（menus には保存しない）。
const kFoodDailyCategory = 'FOOD_DAILY';

const kFoodQuickPrices = [300, 400, 500, 900];

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
