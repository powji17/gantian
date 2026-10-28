import 'package:shared_preferences/shared_preferences.dart';

class DeviceName {
  static const _key = 'device_name';

  static Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  static Future<void> save(String name) async =>
      (await SharedPreferences.getInstance()).setString(_key, name.trim());
}