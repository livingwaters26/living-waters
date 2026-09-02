import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Small local settings file - right now just holds the optional Anthropic
/// API key used by the teleprompter's "Analyze for Emphasis" feature. Kept
/// separate from SimpleStorage's app-data files since this is
/// configuration, not content, and deliberately just a flat key/value JSON
/// file rather than pulling in a whole preferences package for one field.
/// Nothing here is ever sent anywhere except directly to Anthropic's API
/// when you explicitly ask for emphasis suggestions.
class SettingsService {
  static const _fileName = 'settings.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<Map<String, dynamic>> _readAll() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final text = await file.readAsString();
    if (text.trim().isEmpty) return {};
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data));
  }

  Future<String?> getAnthropicApiKey() async {
    final data = await _readAll();
    final key = data['anthropicApiKey'] as String?;
    return (key == null || key.trim().isEmpty) ? null : key.trim();
  }

  Future<void> setAnthropicApiKey(String? key) async {
    final data = await _readAll();
    if (key == null || key.trim().isEmpty) {
      data.remove('anthropicApiKey');
    } else {
      data['anthropicApiKey'] = key.trim();
    }
    await _writeAll(data);
  }

  /// Which backlight colour the player screens glow (round 33) - an index
  /// into StereoBacklight.presets, not a raw colour value, so the stored
  /// setting stays valid if the palette is ever retuned. Defaults to 0.
  Future<int> getBacklightIndex() async {
    final data = await _readAll();
    final value = data['backlightIndex'];
    return value is int ? value : 0;
  }

  Future<void> setBacklightIndex(int index) async {
    final data = await _readAll();
    data['backlightIndex'] = index;
    await _writeAll(data);
  }
}
