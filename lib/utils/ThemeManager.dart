import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

TextTheme txtTheme = (ThemeData.dark()).textTheme;
Color f = SystemTheme.accentColor.accent;
ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: f,
    onPrimary: const Color(0xffc0eeff),

    secondary: f, //dont
    onSecondary: Color(0xffeeeaff),//dont

    background: const Color(0xFF1a1c20), //Второстепенный
    onBackground: Color(0xff725cff),

    surface: const Color(0xFF1a1c20),
    onSurface: Colors.white,


    error: Colors.red,
    onError: Colors.white,
);

var darkTheme = ThemeData.from(
    textTheme: txtTheme,
    colorScheme: colorScheme,
    useMaterial3: true,
).copyWith(
  scaffoldBackgroundColor: const Color(0xFF131517), //# 131517 Главный фон

  dividerColor: const Color(0xFF2d2f32),
  dividerTheme: const DividerThemeData(
    color: Color(0xFF2d2f32),
  ),
);
var lightTheme= ThemeData.light();

class ThemeManager extends ChangeNotifier {
  ThemeData _themeData;
  ThemeManager(this._themeData);

  get getTheme => _themeData;

  get isDark => _themeData == darkTheme;

  void setTheme(ThemeData theme) {
    _themeData = theme;
    notifyListeners();
  }
}