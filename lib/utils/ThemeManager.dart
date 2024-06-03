import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

class ThemeManager extends ChangeNotifier {
  late ThemeData _themeData;

  late ThemeData darkTheme;
  late ThemeData lightTheme;

  ThemeManager(){
    Color f = SystemTheme.accentColor.accent;
    darkTheme = ThemeData.from(
      textTheme: (ThemeData.dark()).textTheme,
      colorScheme: ColorScheme.fromSeed(
          seedColor: f,
          brightness: Brightness.dark
      ).copyWith(
        // onPrimary: const Color(0xffc0eeff), //Дырка кнопки

        secondary: f, //dont
        onSecondary: Color(0xffeeeaff),//dont

        background: const Color(0xFF1a1c20), //Второстепенный
        onBackground: Color(0xff725cff),

        surface: const Color(0xFF1a1c20),
        onSurface: Colors.white,
      ),
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: const Color(0xFF131517), //# 131517 Главный фон

      dividerColor: const Color(0xFF2d2f32),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2d2f32),
      ),
    );

    lightTheme = ThemeData.light();

    _themeData = darkTheme;
  }

  get getTheme => _themeData;

  get isDark => _themeData == darkTheme;

  void setTheme(ThemeData theme) {
    _themeData = theme;
    notifyListeners();
  }
}