import 'package:shared_preferences/shared_preferences.dart';

class RecentNumbers {
  static const _key = 'recent_numbers';
  static const _max = 8;

  static Future<List<String>> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_key) ?? [];
  }

  static Future<void> add(String number) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    list.remove(number);
    list.insert(0, number);
    await p.setStringList(_key, list.take(_max).toList());
  }
}
