// 非Web環境では仮名・英字を正規化した文字列順にフォールバックする。
String _key(String value) => String.fromCharCodes(
  value.trim().toLowerCase().runes.map(
    (r) => r >= 0x30a1 && r <= 0x30f6 ? r - 0x60 : r,
  ),
);

int compareNames(String a, String b) => _key(a).compareTo(_key(b));
