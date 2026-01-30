// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appbarSearch => 'Поиск...';

  @override
  String get home_reader_dialog_title => 'Произошла ошибка';

  @override
  String get home_reader_dialog_error_prefix => 'Ошибка:';

  @override
  String get home_reader_dialog_error_description =>
      'Если эта ошибка будет повторяться, просто напишите нам в телеграме или дискорде';

  @override
  String get home_reader_dialog_error_buttons_ok => 'Ок';

  @override
  String get home_reader_form_select_file_mobile0 => 'Выбери файл';

  @override
  String get home_reader_form_select_file_desktop0 => 'Перетащите';

  @override
  String get home_reader_form_select_file_desktop1 => 'или';

  @override
  String get home_reader_form_select_file_desktop2 => 'Укажите ссылку';

  @override
  String get home_main_categories_start_title => 'Давайте начнем с...';

  @override
  String get home_main_categories_start_description =>
      'Внутри категорий вы можете создавать идеи, проекты, заметки для них и многое другое';

  @override
  String get home_main_categories_buttons_create => 'Создать';

  @override
  String get home_main_categories_block_fast_preview => 'Предпросмотр';
}
