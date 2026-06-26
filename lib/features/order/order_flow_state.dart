import '../../core/menu_category_catalog.dart';
import '../../models/menu_item.dart';
import '../../models/person_option.dart';

const kTequilaOthersCategory = 'TEQUILA_OTHERS';
const kFoodDailyCategory = 'FOOD_DAILY';
const kGoodsCategory = 'DARTS_GOODS';

class DraftOrderLine {
  const DraftOrderLine({required this.menu, required this.qty});

  final MenuItem menu;
  final int qty;

  DraftOrderLine copyWith({int? qty}) {
    return DraftOrderLine(menu: menu, qty: qty ?? this.qty);
  }

  int get lineTotal => menu.priceTaxIncluded * qty;
}

class OrderFlowState {
  OrderFlowState({
    this.person,
    Map<String, DraftOrderLine>? draftOrders,
  }) : draftOrders = Map<String, DraftOrderLine>.from(draftOrders ?? {});

  PersonOption? person;
  MenuItem? selectedMenu;
  int qty = 1;
  final Map<String, DraftOrderLine> draftOrders;

  int get draftTotal =>
      draftOrders.values.fold(0, (sum, line) => sum + line.lineTotal);

  int get draftCount =>
      draftOrders.values.fold(0, (sum, line) => sum + line.qty);

  int get currentLineTotal =>
      selectedMenu == null ? 0 : selectedMenu!.priceTaxIncluded * qty;

  void selectMenu(MenuItem menu) {
    selectedMenu = menu;
    qty = 1;
  }

  void clearCurrentSelection() {
    selectedMenu = null;
    qty = 1;
  }

  void addCurrentLineToDraft() {
    final menu = selectedMenu;
    if (menu == null || qty <= 0) return;
    final existing = draftOrders[menu.id];
    if (existing == null) {
      draftOrders[menu.id] = DraftOrderLine(menu: menu, qty: qty);
    } else {
      draftOrders[menu.id] = existing.copyWith(qty: existing.qty + qty);
    }
    clearCurrentSelection();
  }

  OrderFlowState copyForSession() {
    return OrderFlowState(person: person, draftOrders: draftOrders);
  }
}

String normalModeCategoryKey(MenuItem item) {
  if (item.category == 'TEQUILA' || item.category == 'OTHERS') {
    return kTequilaOthersCategory;
  }
  return item.category;
}

String normalModeCategoryLabel(String categoryKey) {
  if (categoryKey == kTequilaOthersCategory) {
    return 'テキーラ他';
  }
  return MenuCategoryCatalog.labelFor(categoryKey);
}
