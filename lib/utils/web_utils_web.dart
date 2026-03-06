// Web implementation using dart:js_interop and package:web
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Opens a URL in a new browser tab.
void openUrlInBrowser(String url) {
  if (url.isEmpty) return;
  final fullUrl = url.startsWith('http') ? url : 'https://$url';
  web.window.open(fullUrl, '_blank');
}

/// Triggers a web file input dialog for CSV selection.
/// [onFileRead] is called with the file content when a file is selected.
void pickCsvFile({required void Function(String fileName, String content) onFileRead}) {
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = '.csv,.txt,text/csv,text/plain';

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.length == 0) return;
    final file = files.item(0)!;

    final reader = web.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      String? text;
      if (result.isA<JSString>()) {
        text = (result as JSString).toDart;
      }
      if (text != null) {
        onFileRead(file.name, text);
      }
    });
    reader.readAsText(file);
  });
  input.click();
}

/// Triggers a web file input dialog for any file type.
/// [onFilePicked] is called with fileName, fileSize, and objectUrl.
void pickAnyFile({required void Function(String fileName, int fileSize, String objectUrl) onFilePicked}) {
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = '*/*';

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.length == 0) return;
    final file = files.item(0)!;
    final objectUrl = web.URL.createObjectURL(file as JSObject);
    onFilePicked(file.name, file.size, objectUrl);
  });
  input.click();
}
