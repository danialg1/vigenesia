import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _darkThemeType = 'dim'; // 'dim' or 'black'

  ThemeMode get themeMode => _themeMode;
  String get darkThemeType => _darkThemeType;

  ThemeNotifier() {
    _loadFromPrefs();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveToPrefs();
    notifyListeners();
  }

  void setDarkThemeType(String type) {
    _darkThemeType = type;
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    int themeModeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeModeIndex];
    
    _darkThemeType = prefs.getString('dark_theme_type') ?? 'dim';
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', _themeMode.index);
    await prefs.setString('dark_theme_type', _darkThemeType);
  }
}
