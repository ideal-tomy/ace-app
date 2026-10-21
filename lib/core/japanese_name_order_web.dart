import 'dart:js_interop';

@JS('Intl.Collator')
extension type _JapaneseCollator._(JSObject _) implements JSObject {
  external factory _JapaneseCollator(String locale);
  external int compare(String a, String b);
}

final _collator = _JapaneseCollator('ja');

int compareNames(String a, String b) => _collator.compare(a.trim(), b.trim());
