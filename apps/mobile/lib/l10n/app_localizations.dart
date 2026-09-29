import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

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
    Locale('ja'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ja, this message translates to:
  /// **'Questra'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In ja, this message translates to:
  /// **'ホーム'**
  String get home;

  /// No description provided for @quest.
  ///
  /// In ja, this message translates to:
  /// **'Quest'**
  String get quest;

  /// No description provided for @trail.
  ///
  /// In ja, this message translates to:
  /// **'Trail'**
  String get trail;

  /// No description provided for @guild.
  ///
  /// In ja, this message translates to:
  /// **'Guild'**
  String get guild;

  /// No description provided for @profile.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール'**
  String get profile;

  /// No description provided for @arc.
  ///
  /// In ja, this message translates to:
  /// **'Arc'**
  String get arc;

  /// No description provided for @discardChangesTitle.
  ///
  /// In ja, this message translates to:
  /// **'変更を破棄しますか？'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesBody.
  ///
  /// In ja, this message translates to:
  /// **'保存していない内容は失われます。'**
  String get discardChangesBody;

  /// No description provided for @continueEditing.
  ///
  /// In ja, this message translates to:
  /// **'編集を続ける'**
  String get continueEditing;

  /// No description provided for @discardAndClose.
  ///
  /// In ja, this message translates to:
  /// **'破棄して閉じる'**
  String get discardAndClose;

  /// No description provided for @requiredField.
  ///
  /// In ja, this message translates to:
  /// **'必須'**
  String get requiredField;

  /// No description provided for @profileCompact.
  ///
  /// In ja, this message translates to:
  /// **'自分'**
  String get profileCompact;

  /// No description provided for @trailEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'まだTrailはありません'**
  String get trailEmptyTitle;

  /// No description provided for @trailEmptyMessage.
  ///
  /// In ja, this message translates to:
  /// **'今日進んだことを、短い言葉から残してみよう。'**
  String get trailEmptyMessage;

  /// No description provided for @createFirstTrail.
  ///
  /// In ja, this message translates to:
  /// **'最初のTrailを残す'**
  String get createFirstTrail;

  /// No description provided for @createTrail.
  ///
  /// In ja, this message translates to:
  /// **'Trailを残す'**
  String get createTrail;

  /// No description provided for @trailHistoryTitle.
  ///
  /// In ja, this message translates to:
  /// **'これまでのTrail'**
  String get trailHistoryTitle;

  /// No description provided for @trailHistoryDescription.
  ///
  /// In ja, this message translates to:
  /// **'進んだ日ごとに、旅の記録を振り返れます。'**
  String get trailHistoryDescription;

  /// No description provided for @trailCount.
  ///
  /// In ja, this message translates to:
  /// **'Trail {count}件'**
  String trailCount(int count);

  /// No description provided for @reflection.
  ///
  /// In ja, this message translates to:
  /// **'振り返り'**
  String get reflection;

  /// No description provided for @starCandidate.
  ///
  /// In ja, this message translates to:
  /// **'大切な記録の候補'**
  String get starCandidate;

  /// No description provided for @image.
  ///
  /// In ja, this message translates to:
  /// **'画像'**
  String get image;

  /// No description provided for @questContext.
  ///
  /// In ja, this message translates to:
  /// **'Quest：{title}'**
  String questContext(String title);

  /// No description provided for @missionContext.
  ///
  /// In ja, this message translates to:
  /// **'Mission：{title}'**
  String missionContext(String title);

  /// No description provided for @taskContext.
  ///
  /// In ja, this message translates to:
  /// **'Task：{title}'**
  String taskContext(String title);

  /// No description provided for @starMemoryCandidate.
  ///
  /// In ja, this message translates to:
  /// **'大切な記録の候補：{reason}'**
  String starMemoryCandidate(String reason);

  /// No description provided for @trailTypeQuest.
  ///
  /// In ja, this message translates to:
  /// **'Questの記録'**
  String get trailTypeQuest;

  /// No description provided for @trailTypeMission.
  ///
  /// In ja, this message translates to:
  /// **'Missionの記録'**
  String get trailTypeMission;

  /// No description provided for @trailTypeArcReflection.
  ///
  /// In ja, this message translates to:
  /// **'Arcとの振り返り'**
  String get trailTypeArcReflection;

  /// No description provided for @trailTypeManual.
  ///
  /// In ja, this message translates to:
  /// **'自分のメモ'**
  String get trailTypeManual;
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
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
