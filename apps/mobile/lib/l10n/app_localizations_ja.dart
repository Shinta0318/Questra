// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Questra';

  @override
  String get home => 'ホーム';

  @override
  String get quest => 'Quest';

  @override
  String get trail => 'Trail';

  @override
  String get guild => 'Guild';

  @override
  String get profile => 'プロフィール';

  @override
  String get arc => 'Arc';

  @override
  String get discardChangesTitle => '変更を破棄しますか？';

  @override
  String get discardChangesBody => '保存していない内容は失われます。';

  @override
  String get continueEditing => '編集を続ける';

  @override
  String get discardAndClose => '破棄して閉じる';

  @override
  String get requiredField => '必須';

  @override
  String get profileCompact => '自分';

  @override
  String get trailEmptyTitle => 'まだTrailはありません';

  @override
  String get trailEmptyMessage => '今日進んだことを、短い言葉から残してみよう。';

  @override
  String get createFirstTrail => '最初のTrailを残す';

  @override
  String get createTrail => 'Trailを残す';

  @override
  String get trailHistoryTitle => 'これまでのTrail';

  @override
  String get trailHistoryDescription => '進んだ日ごとに、旅の記録を振り返れます。';

  @override
  String trailCount(int count) => 'Trail $count件';

  @override
  String get reflection => '振り返り';

  @override
  String get starCandidate => '大切な記録の候補';

  @override
  String get image => '画像';

  @override
  String questContext(String title) => 'Quest：$title';

  @override
  String missionContext(String title) => 'Mission：$title';

  @override
  String taskContext(String title) => 'Task：$title';

  @override
  String starMemoryCandidate(String reason) => '大切な記録の候補：$reason';

  @override
  String get trailTypeQuest => 'Questの記録';

  @override
  String get trailTypeMission => 'Missionの記録';

  @override
  String get trailTypeArcReflection => 'Arcとの振り返り';

  @override
  String get trailTypeManual => '自分のメモ';
}
