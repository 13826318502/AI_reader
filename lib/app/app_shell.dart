part of '../main.dart';

class ArcReaderApp extends StatefulWidget {
  const ArcReaderApp({super.key});
  @override
  State<ArcReaderApp> createState() => _ArcReaderState();
}

class _ArcReaderState extends State<ArcReaderApp> {
  int tab = 0;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = const [Shelf(), Works(), Gallery(), Worlds(), Mine()];
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      fontFamily: 'serif',
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: gold),
    );
    final darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      home: ValueListenableBuilder<bool>(
        valueListenable: appDarkMode,
        builder: (_, dark, __) => Theme(
          data: dark ? darkTheme : lightTheme,
          child: Scaffold(
            body: pages[tab],
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  label: '书架',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  label: '作品',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  label: 'AI生图',
                ),
                NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  label: '设定集',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: '我的',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget cover(String asset, {double width = 76, double height = 104}) =>
    ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: asset.isEmpty
          ? Container(
              width: width,
              height: height,
              color: const Color(0xFFE8DED0),
              child: const Icon(Icons.menu_book_outlined, color: gold),
            )
          : SizedBox(
              width: width,
              height: height,
              child: AiImagePreview(image: asset, fit: BoxFit.cover),
            ),
    );
Widget card(Widget child) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: surface,
    border: Border.all(color: const Color(0xFFE5D8C2)),
    borderRadius: BorderRadius.circular(16),
  ),
  child: child,
);
