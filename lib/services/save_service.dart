import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';

/// حفظ واستعادة اللعبة محليا على الجهاز.
class SaveService {
  static const String _key = 'ottoman_save';

  Future<void> save(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // ملف الحفظ تالف: نتجاهله ولا نوقف اللعبة
    }
    return null;
  }

  /// يحفظ الحالة كاملة (المؤشرات والجولة والسجل).
  Future<void> saveState(GameState state) => save(state.toJson());

  /// يستعيد الحالة المحفوظة أو null إذا لا يوجد حفظ صالح.
  Future<GameState?> loadState() async {
    final data = await load();
    if (data == null) return null;
    try {
      return GameState.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  String exportJson(Map<String, dynamic> data) => jsonEncode(data);
}
