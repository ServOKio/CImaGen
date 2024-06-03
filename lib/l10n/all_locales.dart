import 'package:flutter/material.dart';

class AllLocale{
  AllLocale();

  static final all = [
    const Locale("en", "US"),
    const Locale("ru", "RU"),
  ];
}

class LocaleProvider with ChangeNotifier {
  Locale _locale = AllLocale.all.first;
  Locale get locale => _locale;
  void setLocale(Locale locale) {
    if (!AllLocale.all.contains(locale)) return;
    _locale = locale;
    notifyListeners();
  }
}