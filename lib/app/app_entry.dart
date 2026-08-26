part of '../main.dart';

/// Application bootstrap lives outside the service layer so startup concerns
/// remain isolated from network and image-generation code.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppErrorLogStore.append(
          error: details.exception,
          stack: details.stack,
          source: 'FlutterError',
          context: details.library ?? '',
          diagnostics: details.toString(),
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        AppErrorLogStore.append(
          error: error,
          stack: stack,
          source: 'PlatformDispatcher',
        );
        return true;
      };
      // Render the shell before optional device and preference initialization.
      // A slow platform channel must never keep the Android splash screen up.
      runApp(const ArcReaderApp());
      unawaited(ThemePreferenceStore.load());
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    },
    (error, stack) {
      AppErrorLogStore.append(
        error: error,
        stack: stack,
        source: 'runZonedGuarded',
      );
    },
  );
}
