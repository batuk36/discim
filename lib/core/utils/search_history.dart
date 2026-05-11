import 'package:shared_preferences/shared_preferences.dart';

class SearchHistory {
  static const _key = 'search_history';
  static const _max = 5;

  static Future<List<String>> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> add(String term) async {
    if (term.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(term.trim());
    list.insert(0, term.trim());
    if (list.length > _max) list.removeLast();
    await prefs.setStringList(_key, list);
  }

  static Future<void> remove(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(term);
    await prefs.setStringList(_key, list);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
