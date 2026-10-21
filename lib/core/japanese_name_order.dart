import 'japanese_name_order_stub.dart'
    if (dart.library.js_interop) 'japanese_name_order_web.dart'
    as platform;

/// 読みを推測せず、表示名を照合する。同名は呼び出し側でID順にする。
int compareJapaneseNames(String a, String b) => platform.compareNames(a, b);
