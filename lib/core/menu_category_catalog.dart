/// メニュー category キー向けの表示名・表示順（Firestore には英語キーのまま保存可能）。
class MenuCategoryCatalog {
  MenuCategoryCatalog._();

  /// チップの左から右への順。未登録カテゴリはこのリストの最後（アルファベット順）に回す。
  static const List<String> displayOrder = [
    'SOUR',
    'SOUR_メガサイズ',
    'TEA_HAI',
    'TEA_HAI_メガサイズ',
    'BEER',
    'SOFT_DRINK',
    'SOFT_DRINK_メガサイズ',
    'COCKTAIL',
    'WHISKY',
    'SHOCHO',
    'CHAMPAGNE',
    'TEQUILA',
    'OTHERS',
  ];

  static const Map<String, String> _labels = {
    'SOUR': 'サワー杯',
    'SOUR_メガサイズ': 'サワー杯（メガ）',
    'TEA_HAI': '茶ハイ',
    'TEA_HAI_メガサイズ': '茶ハイ（メガ）',
    'BEER': 'ビール',
    'SOFT_DRINK': 'ソフトドリンク',
    'SOFT_DRINK_メガサイズ': 'ソフトドリンク（メガ）',
    'COCKTAIL': 'カクテル',
    'TEQUILA': 'テキーラ',
    'WHISKY': 'ウイスキー',
    'SHOCHO': '焼酎',
    'CHAMPAGNE': 'シャンパン',
    'OTHERS': 'アザー',
  };

  static String labelFor(String categoryKey) =>
      _labels[categoryKey] ?? categoryKey;

  static int _rank(String key) {
    final i = displayOrder.indexOf(key);
    if (i >= 0) return i;
    return displayOrder.length;
  }

  static int compareKeys(String a, String b) {
    final ra = _rank(a);
    final rb = _rank(b);
    final c = ra.compareTo(rb);
    if (c != 0) return c;
    return a.compareTo(b);
  }
}
