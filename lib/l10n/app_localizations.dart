import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @appbarSearch.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get appbarSearch;

  /// No description provided for @home_reader_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'An error has occurred'**
  String get home_reader_dialog_title;

  /// No description provided for @home_reader_dialog_error_prefix.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get home_reader_dialog_error_prefix;

  /// No description provided for @home_reader_dialog_error_description.
  ///
  /// In en, this message translates to:
  /// **'If this error continues to occur, just write to us in a telegram or discord'**
  String get home_reader_dialog_error_description;

  /// No description provided for @home_reader_dialog_error_buttons_ok.
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get home_reader_dialog_error_buttons_ok;

  /// No description provided for @home_reader_form_select_file_mobile0.
  ///
  /// In en, this message translates to:
  /// **'Select a file'**
  String get home_reader_form_select_file_mobile0;

  /// No description provided for @home_reader_form_select_file_desktop0.
  ///
  /// In en, this message translates to:
  /// **'Drag-n-Drop to unload'**
  String get home_reader_form_select_file_desktop0;

  /// No description provided for @home_reader_form_select_file_desktop1.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get home_reader_form_select_file_desktop1;

  /// No description provided for @home_reader_form_select_file_desktop2.
  ///
  /// In en, this message translates to:
  /// **'Enter URL'**
  String get home_reader_form_select_file_desktop2;

  /// No description provided for @home_main_categories_start_title.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start with...'**
  String get home_main_categories_start_title;

  /// No description provided for @home_main_categories_start_description.
  ///
  /// In en, this message translates to:
  /// **'Inside the categories, you can create ideas, projects, notes for them, and more'**
  String get home_main_categories_start_description;

  /// No description provided for @home_main_categories_buttons_create.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get home_main_categories_buttons_create;

  /// No description provided for @home_main_categories_block_fast_preview.
  ///
  /// In en, this message translates to:
  /// **'Quick preview'**
  String get home_main_categories_block_fast_preview;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
