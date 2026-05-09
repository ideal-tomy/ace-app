import 'dart:convert';
// Web-only shim: BOM CSV download triggers browser APIs.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// UTF-8 BOM 付きでブラウザに CSV をダウンロードさせる。
void downloadCsvUtf8Bom({required String filename, required String csvBody}) {
  const bom = '\uFEFF';
  final bytes = utf8.encode('$bom$csvBody');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
