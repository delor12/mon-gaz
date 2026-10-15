import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String keyToken = 'sg_auth_token';
  static const String keyDeviceIp = 'sg_device_ip';
  static const String keyDemoMode = 'sg_demo_mode';
  static const String keyCurrency = 'sg_currency';
  static const String keyBottlePrice = 'sg_bottle_price';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyToken);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyToken, token);
  }

  static Future<String> getDeviceIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDeviceIp) ?? 'smartgas.local';
  }

  static Future<void> setDeviceIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDeviceIp, ip);
  }

  static Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyDemoMode) ?? false;
  }

  static Future<void> setDemoMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyDemoMode, enabled);
  }

  static Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCurrency) ?? '€';
  }

  static Future<double> getBottlePrice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(keyBottlePrice) ?? 32.0;
  }
}
