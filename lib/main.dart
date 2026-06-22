import 'package:flutter/material.dart';
import 'Screens/login.dart';
import 'Notifier/theme_notifier.dart';

// Global instance to allow easy access without Provider context
final themeNotifier = ThemeNotifier();

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.themeMode,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: Colors.grey.shade100,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 1,
            ),
            cardColor: Colors.white,
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: themeNotifier.darkThemeType == 'black' ? Colors.black : const Color(0xFF15202B),
            appBarTheme: AppBarTheme(
              backgroundColor: themeNotifier.darkThemeType == 'black' ? Colors.black : const Color(0xFF15202B),
              foregroundColor: Colors.white,
              elevation: 1,
            ),
            cardColor: themeNotifier.darkThemeType == 'black' ? Colors.black : const Color(0xFF1E2732),
            bottomSheetTheme: BottomSheetThemeData(
              backgroundColor: themeNotifier.darkThemeType == 'black' ? const Color(0xFF16181C) : const Color(0xFF1E2732),
            ),
          ),
          home: const Login(),
        );
      },
    );
  }
}
