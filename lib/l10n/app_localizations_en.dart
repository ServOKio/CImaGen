// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appbarSearch => 'Search...';

  @override
  String get home_reader_dialog_title => 'An error has occurred';

  @override
  String get home_reader_dialog_error_prefix => 'Error';

  @override
  String get home_reader_dialog_error_description =>
      'If this error continues to occur, just write to us in a telegram or discord';

  @override
  String get home_reader_dialog_error_buttons_ok => 'Ok';

  @override
  String get home_reader_form_select_file_mobile0 => 'Select a file';

  @override
  String get home_reader_form_select_file_desktop0 => 'Drag-n-Drop to unload';

  @override
  String get home_reader_form_select_file_desktop1 => 'or';

  @override
  String get home_reader_form_select_file_desktop2 => 'Enter URL';

  @override
  String get home_main_categories_start_title => 'Let\'s start with...';

  @override
  String get home_main_categories_start_description =>
      'Inside the categories, you can create ideas, projects, notes for them, and more';

  @override
  String get home_main_categories_buttons_create => 'Create new';

  @override
  String get home_main_categories_block_fast_preview => 'Quick preview';
}
