import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

TextTheme txtTheme = (ThemeData.dark()).textTheme;
Color f = SystemTheme.accentColor.accent;
ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: f,
    onPrimary: const Color(0xffc0eeff),

    secondary: Color(0xff6c9867), //dont
    onSecondary: Color(0xffeeeaff),//dont

    background: Color(0xff1A1A1A),
    onBackground: Color(0xff725cff),

    surface: Color(0xFF222222),
    onSurface: Color(0xffe2dbff),

    error: Colors.red,
    onError: Colors.white,
);

var darkTheme = ThemeData.from(
    textTheme: txtTheme,
    colorScheme: colorScheme,
    useMaterial3: true,
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