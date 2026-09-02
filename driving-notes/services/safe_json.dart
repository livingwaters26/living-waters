import 'dart:convert';
import 'dart:io';

/// Best-effort JSON list loader. A crashed or partial write should not kill the app.
class SafeJson {
  static Future<List<dynamic>> readList(File file) async {
    if (!await file.exists()) return [];
    var text = await file.readAsString();
    text = text.trim();
    if (text.isEmpty) return [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded;
      return [];
    } catch (_) {
      final start = text.indexOf('[');
      if (start < 0) {
        await _backup(file, text);
        return [];
      }
      for (var end = text.lastIndexOf(']'); end > start; end = text.lastIndexOf(']', end - 1)) {
        try {
          final decoded = jsonDecode(text.substring(start, end + 1));
          if (decoded is List) {
            await _backup(file, text);
            await file.writeAsString(jsonEncode(decoded));
            return decoded;
          }
        } catch (_) {}
      }
      await _backup(file, text);
      return [];
    }
  }

  static Future<void> _backup(File file, String text) async {
    try {
      await File('${file.path}.bad').writeAsString(text);
    } catch (_) {}
  }
}
