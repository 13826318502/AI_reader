part of '../../main.dart';

class ReadingPreferencesStore {
  static double fontSize = 18;
  static bool immersive = true;
  static bool pageTurn = true;
  static bool eyeCare = false;
  static String theme = 'paper';
  static String pageMode = 'curl';
  static double lineHeight = 2.05;
  static double horizontalPadding = 22;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    fontSize = p.getDouble('reading_font_size') ?? 18;
    immersive = p.getBool('reading_immersive') ?? true;
    pageTurn = p.getBool('reading_page_turn') ?? true;
    eyeCare = p.getBool('reading_eye_care') ?? false;
    theme = p.getString('reading_theme') ?? 'paper';
    pageMode = p.getString('reading_page_mode') ?? 'curl';
    lineHeight = p.getDouble('reading_line_height') ?? 2.05;
    horizontalPadding = p.getDouble('reading_horizontal_padding') ?? 22;
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('reading_font_size', fontSize);
    await p.setBool('reading_immersive', immersive);
    await p.setBool('reading_page_turn', pageTurn);
    await p.setBool('reading_eye_care', eyeCare);
    await p.setString('reading_theme', theme);
    await p.setString('reading_page_mode', pageMode);
    await p.setDouble('reading_line_height', lineHeight);
    await p.setDouble('reading_horizontal_padding', horizontalPadding);
  }
}
