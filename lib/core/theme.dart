part of '../main.dart';

class ThemePreferenceStore {
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    appDarkMode.value = p.getBool('app_dark_mode') ?? false;
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('app_dark_mode', appDarkMode.value);
  }
}

Color get background =>
    appDarkMode.value ? const Color(0xFF101820) : const Color(0xFFF7F1E6);
Color get surface =>
    appDarkMode.value ? const Color(0xFF1B2935) : const Color(0xFFFFFBF3);
Color get mutedText => appDarkMode.value ? Colors.white70 : Colors.black54;
Color get primaryText => appDarkMode.value ? Colors.white : Colors.black87;
const gold = Color(0xFFD99222);
